# Package 开发权威指南

本文档是开发 Wish 包的权威参考。它涵盖了从基础配置到高级设计模式的全方位指导，旨在帮助开发者构建健壮、可维护的生产环境。

## 1. 核心理念：静态声明与动态执行

理解 Wish 的**双阶段解析机制**是开发高质量包的前提。

### 1.1 静态声明阶段 (The Declaration Phase)
*   **目的**: 构建依赖图 (Dependency Graph)。
*   **机制**: Wish 读取 `package.py` 源码，使用 AST (抽象语法树) 提取 `req`, `ava`, `ban` 等关键字。
*   **关键限制**: **所有 Python 流程控制语句 (if, for, try) 在此阶段均被忽略。**
*   **最佳实践**: 所有的依赖关系必须是声明式的，不依赖运行时状态。

### 1.2 动态执行阶段 (The Execution Phase)
*   **目的**: 配置运行时环境 (Environment Setup)。
*   **机制**: 依赖解析完成后，Wish 按拓扑序执行被选中包的 `package.py`。
*   **能力**: 拥有完整的 Python 运行时权限（文件读写、环境变量修改）。
*   **最佳实践**: 所有的路径配置、文件操作、环境初始化都应写在这里。

---

## 2. 目录结构与规范

标准包结构如下：

```
packages/
└── <package_name>/          # 包名 (小写，连字符)
    └── <version_tag>/       # 版本号 (建议 SemVer + 平台后缀)
        ├── package.py       # [必须] 定义文件
        ├── src/             # [可选] 源码或二进制存放目录
        │   ├── bin/
        │   └── lib/
        └── LICENSE          # [可选] 许可证
```

### 2.1 版本命名规范
推荐使用 `X.Y.Z.platform.build` 格式：
*   **X.Y.Z**: 上游软件版本 (如 `3.10.6`)。
*   **platform**: 平台标识 (`lin`, `win`, `mac`)，用于人类快速识别（机器识别靠 `ava`）。
*   **build**: 内部构建号 (`0`, `1`, `2`)，用于修复包本身的问题而不改变上游版本。

---

## 3. 设计模式 (Design Patterns)

### 3.1 跨平台策略 (The Cross-Platform Strategy)

**问题**: 如何让同一个包在 Windows 和 Linux 上表现不同？

**方案 A: 拆分包 (推荐)**
创建两个独立的包版本，利用 `ava` 进行互斥。
*   `packages/mypkg/1.0.win/package.py`:
    ```python
    req("win-api")
    ava("platform=windows")
    # 执行阶段
    env("PATH").insert(os.path.join(this.root, "Scripts"))
    ```
*   `packages/mypkg/1.0.lin/package.py`:
    ```python
    req("linux-api")
    ava("platform=linux")
    # 执行阶段
    env("PATH").insert(os.path.join(this.root, "bin"))
    ```

**方案 B: 内部判断 (仅限执行阶段)**
如果依赖相同，仅环境变量路径不同，可以在一个文件中通过 `if` 处理。
```python
# package.py
req("common-lib") # 依赖必须相同

import sys
if sys.platform == "win32":
    folder = "Scripts"
else:
    folder = "bin"

env("PATH").insert(os.path.join(this.root, folder))
```

### 3.2 宿主伪装模式 (The Host Masquerade Pattern)

**场景**: 你的团队已经安装了 Maya 2024 到 `/usr/autodesk/maya2024`，你不想重新打包上传到 Wish 仓库，但想用 Wish 管理其环境。

**实现**:
创建一个 "Shim Package" (垫片包)。

```python
# packages/maya/2024.shim/package.py
import os

# 1. 声明自身替代了 maya=2024
alt("maya=2024")

# 2. 定义本地路径
local_path = "/usr/autodesk/maya2024/bin/maya"

# 3. 检查并桥接
if os.path.exists(local_path):
    # 将本地路径加入 PATH
    env("PATH").insert(os.path.dirname(local_path))
    # 别名指向本地文件
    alias("maya", local_path)
    print("Using local Maya from system.")
else:
    # 优雅回退：如果本地没装，尝试拉取真正的远程包（如果存在）
    # 或者直接报错提示用户安装
    raise Exception(f"Local Maya not found at {local_path}")
```

### 3.3 插件触发器 (The Plugin Trigger)

**场景**: 你开发了一个名为 `mtoa` (Arnold for Maya) 的渲染器。你希望：
1.  用户请求 `wish maya mtoa` 时能用。
2.  用户请求 `wish maya` 时，如果有许可证，也能自动加载。

**实现**:
利用 `ext` 的反向依赖注入。

```python
# packages/mtoa/5.0/package.py
req("arnold-core")

# 声明：我是 maya 的扩展
# 只有当环境中存在 maya>=2022 时，才尝试注入我
# 这里的 @maya 是触发器
ext("mtoa-maya-plugin@maya>=2022")
```

---

## 4. 环境变量管理进阶

`env()` 函数不仅仅是简单的设置，它还处理了复杂的继承逻辑。

### 4.1 列表操作
*   **`insert(path)`**: 插入头部。对于 `PATH`, `PYTHONPATH` 等搜索路径，这意味着**高优先级**。Wish 默认使用此方式确保当前包覆盖系统包。
*   **`append(path)`**: 追加尾部。用于提供默认回退选项。
*   **`prepend(path)`**: (等同于 insert) 显式强调插入头部。

### 4.2 独占与清理
*   **`setenv(value)`**: 强制覆盖。用于 `MAYA_VERSION=2024` 这种单一值变量。
*   **`unload(prefix)`**: **非常强大**。用于清理从父进程（如系统终端）继承来的污染。
    ```python
    # 清理所有指向旧 Python 环境的路径
    env("PYTHONPATH").unload("/usr/lib/python")
    env("PYTHONPATH").unload("C:\\Python")
    ```

### 4.3 高级环境操作 (Advanced Env Operations)
在复杂的管线中，有时需要更精细地控制变量的合并行为：

*   **`prepend(path)`**: 显式地将路径置于变量的最前端。这在需要覆盖所有已存在路径（包括其他包设置的路径）时非常有用。
*   **`unload(prefix)`**: **非常强大**。用于清理从父进程（如系统终端）继承来的污染。支持基于模式的卸载，确保运行时环境的纯净性，防止“环境中毒”。
    ```python
    # 清理所有指向旧 Python 环境的路径
    env("PYTHONPATH").unload("/usr/lib/python")
    env("PYTHONPATH").unload("C:\\Python")
    ```

---

## 5. 可重现性与版本锁定 (Reproducibility & Locking)

Wish 鼓励使用精确的版本控制来实现环境的可重现性。

*   **版本锁定**: 在 CI/CD 脚本中，始终使用 `==` 运算符。
    ```bash
    wish python==3.10.6 - python
    ```
*   **Lockfile**: Wish 目前不自动生成 lockfile，但推荐将最终的解析结果 (Solution) 导出并固化。

## 6. 测试你的包 (Testing Your Package)

在发布包之前，建议进行本地测试。为了保证测试的准确性，应当在**隔离环境 (Isolated Env)** 中进行：

1.  **语法检查**: 运行 `wish -c "import packages.mypkg.package"` (假设在 correct path 下) 或者简单地 `wish +` 看是否有解析错误。
2.  **环境验证**:
    ```bash
    # 模拟环境加载
    export WISH_DEVELOP_MODE=1
    wish mypkg - printenv | grep MY_VAR
    ```
3.  **隔离环境测试 (Isolating Env)**:
    使用 `--pure` 或 `--clean` 参数启动 Wish，强制忽略所有继承自宿主系统的环境变量（除了必要的系统变量），确保包在纯净环境下依然能正常工作。
    ```bash
    wish --pure mypkg - python -c "import mypkg; print('Success')"
    ```
4.  **加载测试**: 确保 `import mypkg` 在 Python 环境中工作正常。

---

## 7. 跨平台注意事项 (Cross-Platform Caveats)

### 7.1 二进制重定位 (Binary Relocation)
在 Linux 上打包预编译的二进制文件时，经常会遇到动态链接库路径问题。

*   **问题**: `RPATH` 硬编码了编译时的绝对路径。
*   **解决**: 使用 `$ORIGIN` 相对路径。在打包前，使用 `patchelf` 修改二进制文件：
    ```bash
    patchelf --set-rpath '$ORIGIN/../lib' bin/mytool
    ```
    这样，无论 Wish 将包安装到哪个目录，工具都能找到随包分发的库。

### 7.2 路径分隔符
在 `package.py` 中，始终使用 `os.path.join` 或正斜杠 `/`。Python 在 Windows 上也能正确处理正斜杠。

---

## 8. Metaprogramming in package.py (Expert-Level)

虽然 Wish 鼓励声明式的依赖定义，但在处理大规模插件系统或动态环境时，利用 Python 的元编程能力可以极大地减少冗余。

### 8.1 动态依赖生成 (Dynamic Dependency Generation)

**场景**: 你的包（如 `maya-render-config`）需要根据支持的渲染器列表动态请求插件包。

**实现**:
利用 Python 循环在解析阶段动态调用 `req()` 或 `ext()`。

```python
# package.py
PLUGINS = ["vray", "arnold", "redshift"]

for plugin in PLUGINS:
    # 动态生成依赖：请求每个渲染器的特定版本
    req(f"{plugin}-maya-plugin>=1.0")
    
    # 或者动态声明扩展
    # ext(f"config-{plugin}@maya")
```

**优势**: 易于维护。增加新插件只需更新 `PLUGINS` 列表，无需手动复制多行 `req`。

### 8.2 解析时环境检查 (Parse-time Environment Inspection)

**场景**: 根据宿主机的环境变量（如 `SITE_ID`）决定加载哪些基础库。

**实现**:
在 `package.py` 顶层直接访问 `os.environ`。

```python
import os

# 警告：这发生在解析阶段 (Declaration Phase)
site = os.environ.get("SITE_ID", "default")

if site == "vancouver":
    req("vc-pipeline-tools")
elif site == "london":
    req("ldn-pipeline-tools")
```

#### ⚠️ 重要警告：风险 vs 收益

*   **风险 (The Risk)**: 
    *   **破坏缓存一致性**: Wish 可能会缓存解析结果。如果 `SITE_ID` 改变但缓存未刷新，环境将处于错误状态。
    *   **不可预测性**: 不同的机器或 Shell 会话可能因为环境变量不同而解析出完全不同的依赖图，导致“在我机器上能跑”的问题。
*   **收益 (The Benefit)**: 
    *   **极致的灵活性**: 允许同一个包在不同物理站点或部门之间自动适配，无需创建多个版本。
*   **最佳实践**: 仅在环境变量**极少变动**（如物理站点 ID、操作系统架构）且无法通过 `ava()` 表达时使用此模式。

---

## 9. Python 模块化工具模式 (The Python Module Pattern)

**场景**：开发一个既可以用作命令行工具 (CLI)，又可以被其他 Python 脚本导入作为库使用的包。

**Package.py 配置**:
```python
# package: confflow/package.py
import os

req("python>=3.6")

# 1. 暴露源码目录到 PYTHONPATH
env("PYTHONPATH").insert(os.path.join(this.root, "src"))

# 2. 定义别名调用模块
alias("confflow", "python3 -m confflow")
```

---

## 10. Gitflow 发布工作流 (Gitflow Workflow)

在企业级环境中，我们推荐使用 `wish gitflow` 命令行工具来管理包的发布，它自动化了以下步骤：

1.  **LFS 处理 (LFS Handling)**: 自动扫描 `src/` 目录，将大于 50MB 的二进制文件提取并上传到 S3/MinIO，避免 Git 仓库膨胀。Wish 会在 Git 仓库中仅保留 LFS 指针，而在发布时自动还原制品 (Artifact)。
2.  **版本打标**: 基于 `package.py` 路径自动生成 Git Tag。
3.  **CI 触发**: 推送代码后，GitLab CI/CD 会自动拉取代码，从 S3 下载 LFS 文件，组合后发布到 Wish 仓库。

**发布命令**:
```bash
# 在包的根目录下
wish gitflow - gitflow -p <project_name> -m "Release message"
```
