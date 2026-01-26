# AGENTS.md - Wish Platform 智能体协作指南

本文档为在 Wish Platform 仓库中工作的自主智能体（AI Agents）提供操作协议、代码规范和工作流指导。
本仓库是一个**纯文档与脚本**仓库，旨在通过 GitLab 直接展示技术文档，不依赖复杂的构建系统。

## 1. 仓库概览与环境

### 1.1 核心结构
*   **`docs/`**: 核心文档库（Markdown 格式）。
    *   **`guide/`**: 用户指南（快速上手、CLI、FAQ）。
    *   **`advanced/`**: 进阶文档（架构、原理、包开发）。
    *   **`images/`**: 文档引用的图片资源。
*   **`platforms/`**: 平台启动脚本（Linux/Windows）。
    *   `linux/wish`: Bash 脚本。
    *   `windows/wish.cmd`: Batch 脚本。

### 1.2 构建与测试
由于本仓库主要用于文档展示和脚本分发，没有编译环节。

*   **文档预览**:
    *   直接读取 Markdown 文件。
    *   **验证链接**: 确保所有 `[Link](path)` 均使用相对路径且指向有效文件。
    *   **验证图片**: 确保图片路径通常为 `../images/filename.png`。

*   **脚本测试**:
    *   **Linux**: `bash platforms/linux/wish --help` (需在 Linux 环境验证)。
    *   **Windows**: `platforms\windows\wish.cmd --help` (需在 Windows 环境验证)。
    *   **注意**: 脚本依赖外部下载的 `packages/` 目录，在纯代码环境中可能仅能运行基础参数检查。

---

## 2. 文档编写规范 (Documentation Style)

### 2.1 语言与格式
*   **语言**: **简体中文** (Simplified Chinese)。
*   **格式**: 标准 GitHub Flavored Markdown (GFM)。
*   **标题**: 使用 `#` (H1) 到 `####` (H4) 层级，保持结构清晰。

### 2.2 链接与资源
*   **相对路径**: 严禁使用绝对路径或 URL 链接仓库内文件。
    *   ✅ 正确: `[快速上手](../guide/quick-start.md)`
    *   ❌ 错误: `[快速上手](/docs/guide/quick-start.md)` (绝对路径在 GitLab 中无效)
*   **图片**: 所有图片存放在 `docs/images/`。
    *   引用格式: `![Alt Text](../images/filename.png)`

### 2.3 内容风格
*   **简洁专业**: 避免冗余的修饰词，直接切入技术细节。
*   **代码块**: 必须指定语言类型，例如:
    ```python
    req("requests")
    ```
*   **提示块**: 使用引用块 `>` 表示重要提示或警告。

---

## 3. 脚本开发规范 (Scripting Guidelines)

### 3.1 Bash (`platforms/linux/`)
*   **Shebang**: `#!/bin/bash`
*   **变量命名**: 环境变量使用 `UPPER_CASE` (如 `WISH_LOCAL`)。
*   **路径处理**: 必须处理空格，始终使用双引号包裹路径变量 (`"$WISH_LOCAL"`).
*   **自举逻辑**: 脚本应能够动态定位自身位置 (`$(dirname "$(readlink -f "$0")")`)。

### 3.2 Batch (`platforms/windows/`)
*   **变量设置**: 使用 `set "VAR=VALUE"` 防止尾随空格。
*   **路径处理**: 使用 `%~dp0` 获取脚本当前目录。
*   **延迟扩展**: 复杂逻辑中建议启用 `EnableDelayedExpansion`。

---

## 4. Wish DSL (Package.py) 生成规范

智能体常需生成 `package.py` 示例，请严格遵守以下 DSL 规范：

### 4.1 核心原语
*   **`req(package)`**: 必需依赖 (AND)。例: `req("python>=3.9")`
*   **`ava(condition)`**: 可用性条件 (OR)。例: `ava("platform=windows")`
*   **`ban(package)`**: 冲突禁止 (NOT)。例: `ban("numpy<1.20")`
*   **`xor(a, b)`**: 互斥选择。例: `xor("PyQt6", "PySide6")`
*   **`ext(package)`**: 扩展注入。例: `ext("vray@maya")`

### 4.2 静态解析原则 (Crucial)
*   **静态性**: 所有依赖声明 (`req`, `ava` 等) **绝不能** 放在 `if/else` 动态逻辑块中。
*   **AST 解析**: Wish 使用 AST 静态分析提取依赖，动态逻辑会被忽略。
*   **示例**:
    ```python
    # ✅ 正确
    req("win-lib")
    ava("platform=windows")

    # ❌ 错误 (if 被忽略，Linux 下也会请求 win-lib)
    if sys.platform == "win32":
        req("win-lib")
    ```

---

## 5. 工作流建议

1.  **文档更新**:
    *   修改 `docs/` 下的 Markdown 文件。
    *   如新增文件，请同步更新 `README.md` 中的索引。
    *   无需运行构建命令，GitLab 会自动渲染。

2.  **重构与清理**:
    *   保持目录结构扁平化。
    *   定期检查并移除未引用的 `images/` 资源。

3.  **智能体自检**:
    *   在提交修改前，检查是否破坏了 Markdown 表格格式。
    *   确认所有超链接在当前目录结构下是有效的。
