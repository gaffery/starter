# 从 Rez/Conda 迁移指南

本文档旨在帮助正在使用 Rez、Conda 或 Pip 的团队平滑迁移到 Wish 平台。

## 1. 核心概念映射

| 概念 | Rez | Conda | Wish | 差异点 |
| :--- | :--- | :--- | :--- | :--- |
| **包定义** | `package.py` | `meta.yaml` | `package.py` | Wish 的 DSL 更严格 (AST 解析)，不支持动态条件。 |
| **环境激活** | `rez-env pkg` | `conda activate env` | `wish pkg - bash` | Wish 环境是临时的，用完即焚；Conda 环境是持久的。 |
| **依赖解析** | 回溯算法 | SAT (近期版本) | **MaxSAT** | Wish 使用权重优先的 MaxSAT，保证全局最优解。 |
| **变体/条件** | `variants` | Build Strings | `ava()` / `req()` | Wish 将所有变体视为独立的节点，通过 `ava` 条件筛选。 |

## 2. 从 Rez 迁移

Rez 用户会感到非常亲切，因为 Wish 也使用 `package.py`。但最大的陷阱在于**动态代码**。

### 2.1 语法对照表

| Rez 写法 | Wish 写法 | 说明 |
| :--- | :--- | :--- |
| `requires = ['python-3.7']` | `req("python==3.7")` | Wish 使用函数调用风格。 |
| `build_command = '...'` | (无直接对应) | Wish 专注于**分发**。构建指令通常放在 CI 脚本中。 |
| `def commands(): env.PATH...` | 直接写在文件顶层 | `env()` 调用写在顶层，仅在执行阶段运行。 |
| `if system.platform == 'windows': ...` | `ava("platform=windows")` | **关键区别**：Wish 禁止在声明依赖时使用 Python `if`。 |

### 2.2 复杂 Rez 变体转换 (Complex Variant Translation)

Rez 使用 `variants` 列表来定义多维度的变体矩阵。在 Wish 中，我们需要将其展开为独立的包版本或使用 `ava` 条件。

**Rez 原文**:
```python
variants = [
    ["platform-linux", "arch-x86_64", "python-3.7"],
    ["platform-windows", "arch-AMD64", "python-3.9"]
]
```

**Wish 转换策略**:
Wish 没有显式的 `variants` 字段。你需要为每种变体生成一个独立的 `package.py`，并使用 `ava` 来区分。

*   **路径**: `packages/mypkg/1.0.lin/package.py`
    ```python
    req("python-3.7")
    ava("platform=linux", "arch=x86_64")
    ```

*   **路径**: `packages/mypkg/1.0.win/package.py`
    ```python
    req("python-3.9")
    ava("platform=windows", "arch=AMD64")
    ```

### 2.3 迁移脚本示例

以下脚本可以辅助将 Rez 的 `package.py` 转换为 Wish 格式的草稿：

```python
# simple_rez_to_wish.py
def migrate(rez_content):
    lines = []
    lines.append('# -*- coding: utf-8 -*-')
    lines.append('import os')
    
    # 转换依赖
    if 'requires' in rez_content:
        reqs = extract_list(rez_content, 'requires')
        req_str = ', '.join([f'"{r}"' for r in reqs])
        lines.append(f'req({req_str})')
        
    # 转换环境变量
    if 'def commands():' in rez_content:
        lines.append('# TODO: 请手动转换 commands() 中的逻辑')
        lines.append('# env.PATH.append("{root}/bin") -> env("PATH").append(os.path.join(this.root, "bin"))')
        
    return '\n'.join(lines)
```

## 3. 从 Conda 迁移

Conda 用户通常习惯于持久化环境。迁移到 Wish 需要转变为"按需激活"的思维。

### 3.1 Environment.yml 转换

Conda 的 `environment.yml` 本质上定义了一个**元包 (Meta-Package)**。

**Conda (environment.yml):**
```yaml
name: my-env
dependencies:
  - python=3.9
  - numpy
  - pytorch
```

**Wish (packages/my-env/1.0/package.py):**
```python
# 定义为元包
req("python=3.9")
req("numpy")
req("pytorch")
```

**使用方式:**
*   旧：`conda activate my-env`
*   新：`wish my-env - bash`

## 4. 从 Pip 迁移

### 4.1 一键转换命令

你可以使用 Python 脚本快速生成 `req()` 列表：

```bash
# 将 requirements.txt 转换为 Wish req() 格式
cat requirements.txt | sed 's/==/=/g' | awk '{print "req(\"" $0 "\")"}'
```

**输出示例:**
```python
req("requests>=2.0")
req("flask=2.2.2")
```

## 5. 最佳迁移策略

我们建议采取**自底向上 (Bottom-Up)** 的迁移策略：

1.  **基础库先行**: 首先将 Python、GCC、CMake 等基础工具打包进入 Wish。
2.  **代理模式过渡**: 对于不想重新编译的大型软件（如 Maya、Nuke），先使用代理模式接入 Wish 管理。
3.  **中间件迁移**: 将内部通用库迁移。
4.  **项目接入**: 最后将具体的业务项目配置为 Wish 包。

> **提示：** 在迁移初期，可以使用 `WISH_DEVELOP_MODE=1` 在本地快速调试 `package.py`。

## 6. 迁移常见问题 (Migration FAQ)

**Q: 我以前的 shell 脚本还可以直接运行吗？**
A: 不可以直接运行。需要将脚本的第一行 shebang 改为 `wish <deps> - bash script.sh`，或者在脚本内部使用 `wish` 激活环境。

**Q: 只有二进制文件没有源码的软件怎么迁移？**
A: 非常简单。创建一个包含该二进制文件的包结构，在 `package.py` 中将二进制路径加入 `PATH` 即可。参考 [代理模式](../advanced/best-practices.md#31-代理模式-the-proxy-pattern)。

**Q: 迁移过程中发现缺少某个系统库怎么办？**
A: 不要依赖宿主机的系统库！请将该系统库（如 `openssl`, `glibc`）也打包成 Wish 包，并声明为依赖。这是实现"可重现构建"的关键。
