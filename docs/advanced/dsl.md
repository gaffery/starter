# DSL 语法速查手册 (Domain Specific Language)

Wish 使用一种基于 Python 的领域特定语言 (DSL) 来定义包的元数据和行为。本文档是该语言的完整参考手册，适合开发者和 AI Agent 查阅。

> **核心原则**: Wish DSL 分为两个互不干扰的阶段：**声明阶段**（用于构建依赖图）和**执行阶段**（用于构建运行时环境）。

## 1. 声明阶段关键字 (Static Declaration)

这些关键字在**静态解析**阶段被提取。它们决定了哪些包会被下载和加载。

**⚠️ 警告**: 这些关键字的参数必须是静态字符串。不要将它们放在 `if/for/try` 块中，否则会导致解析器行为不符合预期（AST 解析会忽略流程控制）。

| 关键字 | 全称 | 逻辑 | 行为描述 | 典型示例 |
| :--- | :--- | :--- | :--- | :--- |
| **`req`** | Require | `AND` | **必需依赖**。当前包工作所必须的其他包。支持版本约束。 | `req("python>=3.9", "numpy")` |
| **`ava`** | Available | `OR` | **可用性条件**。只有当所有条件都满足时，当前包才会被纳入计算。常用于区分平台。 | `ava("platform=linux", "arch=x86_64")` |
| **`ban`** | Ban | `NOT` | **冲突禁止**。如果目标包存在，则当前包不可用。用于解决版本冲突或替代品冲突。 | `ban("pillow<9.0")` |
| **`xor`** | Exclusive OR | `XOR` | **互斥选择**。强制在给定列表中**选且仅选**一个。常用于多后端选择（如 Qt5 vs Qt6）。 | `xor("PyQt5", "PySide2")` |
| **`alt`** | Alternative | `Fallback` | **替代提供**。声明当前包提供了某个虚拟能力（如 `ssl-api`）。当其他包请求该能力时，当前包可作为候选。 | `alt("openssl-api")` |
| **`ext`** | Extension | `Inject` | **动态扩展**。这是一种反向依赖：如果环境满足条件（通常是存在某个宿主包），则自动注入指定的扩展包。 | `ext("vray@maya")` |

### 1.1 版本约束语法

| 符号 | 含义 | 示例 | 说明 |
| :--- | :--- | :--- | :--- |
| `=` | 前缀匹配 | `python=3.9` | 匹配 `3.9.0`, `3.9.1`, `3.9.13` 等所有 `3.9` 开头的版本。 |
| `==` | 精确匹配 | `python==3.9.1` | 仅匹配 `3.9.1`。 |
| `>=` | 大于等于 | `numpy>=1.20` | 匹配 `1.20.0` 及以上。 |
| `<` | 小于 | `numpy<2.0` | 匹配所有小于 `2.0` 的版本。 |
| `!=` | 排除 | `lib!=1.0.0` | 排除特定故障版本。 |

### 1.2 高级逻辑场景 (Advanced Logic)

#### 1.2.1 互斥与条件的组合 (XOR + AVA)
当你需要根据平台自动选择互斥项时，这是最高级的用法。

**场景**: Windows 上必须用 D3D 后端，Linux 上必须用 OpenGL 后端。

```python
# package: my-app/1.0/package.py
req("graphics-backend")

# package: backend-d3d/1.0/package.py
alt("graphics-backend")
ava("platform=windows")

# package: backend-gl/1.0/package.py
alt("graphics-backend")
ava("platform=linux")
```
Wish 求解器会自动推导：在 Windows 上，由于 `backend-gl` 不可用 (unavailable)，`alt` 只能解析为 `backend-d3d`。

---

## 2. 执行阶段对象 (Runtime Execution)

这些对象和函数仅在环境构建阶段（依赖解析完成后）执行。此时可以使用完整的 Python 功能（文件 IO、子进程、逻辑判断）。

### 2.1 上下文对象 (`this`)

`this` 提供了当前正在执行的包的元数据。

| 属性 | 类型 | 说明 | 用途示例 |
| :--- | :--- | :--- | :--- |
| `this.name` | `str` | 包名称 | 打印日志: `print(f"Loading {this.name}")` |
| `this.tags` | `str` | 完整版本标签 | 获取版本: `ver = this.tags.split('.')[0]` |
| `this.root` | `str` | **包安装根目录 (绝对路径)** | 构建路径: `bin = os.path.join(this.root, "bin")` |
| `this.init` | `bool` | **首次安装标志** | 初始化钩子: `if this.init: download_assets()` |

### 2.2 环境变量操作 (`env`)

`env(key)` 返回一个操作对象，支持链式调用。修改仅对当前 Wish 会话的子进程生效，**不污染**宿主机。

*   **`.insert(path)`**: 插入到值的前面（高优先级）。自动处理路径分隔符（Linux `:`, Windows `;`）。
    ```python
    # /opt/pkg/bin:/usr/bin
    env("PATH").insert(os.path.join(this.root, "bin"))
    ```
*   **`.prepend(path)`**: `insert` 的别名。
*   **`.append(path)`**: 追加到值的后面（低优先级）。通常用于提供回退路径。
    ```python
    # /usr/bin:/opt/pkg/bin
    env("PATH").append(os.path.join(this.root, "bin"))
    ```
*   **`.setenv(value)`**: 强制设置/覆盖变量值。
    ```python
    env("MY_APP_HOME").setenv(this.root)
    ```
*   **`.remove(value)`**: 从变量中移除指定值。
*   **`.unload(prefix)`**: 移除所有以 `prefix` 开头的路径。常用于清理旧环境残留。

### 2.3 命令别名 (`alias`)

为当前环境创建快捷命令。

```python
# 将 'mytool' 映射到具体的可执行文件
alias("mytool", os.path.join(this.root, "bin", "tool_v1"))

# 也可以映射复杂的命令串
alias("ll", "ls -l")
```

---

## 3. 常见陷阱与调试

### 3.1 ❌ 陷阱：在 `if` 中使用 `req`

**错误代码**:
```python
import sys
# 错误：AST 解析器看不懂 if，这行 req 会被无条件提取！
if sys.platform == "win32":
    req("windows-lib")
```

**后果**: Linux 用户也会被迫下载 `windows-lib`，导致解析失败。

**✅ 正确做法**: 使用 `ava`。
```python
req("windows-lib")
# 正确：告诉求解器，这个包本身只在 Windows 上有效
ava("platform=windows")
```

### 3.2 ❌ 陷阱：硬编码路径

**错误代码**:
```python
env("PATH").insert("/opt/wish/packages/mypkg/1.0/bin")
```

**后果**: 无法跨平台，无法迁移安装目录。

**✅ 正确做法**: 使用 `this.root`。
```python
env("PATH").insert(os.path.join(this.root, "bin"))
```

### 3.3 调试技巧

*   **语法检查**: 运行 `wish <pkg> +`。如果 `package.py` 有 Python 语法错误，会在加载阶段报错 `CONFIG_ERROR`。
*   **依赖检查**: 使用 `wish search <pkg>` 查看提取出的静态依赖列表，确认 `req/ava` 是否正确被识别。
