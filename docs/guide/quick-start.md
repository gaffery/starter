# 快速上手指南

本文档将带你从零开始，在 5 分钟内体验 WISH 的强大能力。

> **核心理念：** Wish 不是传统包管理器。它是一个**环境激活系统**——你告诉它需要什么包，它就为你的命令构建一个完美的执行环境。

## 1. 安装与配置

### 1.1 获取 Wish

```bash
git clone https://github.com/your-org/wishtools.git /opt/wishtools
export PATH="/opt/wishtools:$PATH"
```

### 1.2 Shell 集成 (Shell Integration)

为了获得最佳体验（如命令补全和快速别名），建议将以下内容添加到你的 `~/.bashrc` 或 `~/.zshrc`：

```bash
# Wish 环境初始化
export WISH_LOCAL="/opt/wishtools"
export PATH="$WISH_LOCAL:$PATH"

# 推荐别名
alias wpy="wish python - python"  # 快速启动 Python
alias wsh="wish - bash"           # 快速进入干净的 Shell 环境
alias wish-search="wish wish-search - search" # 启用搜索功能
```

执行 `source ~/.bashrc` 即可生效。

### 1.3 最小化配置 (用于测试)

```bash
# 所有的包和缓存都放在用户目录下，无需 root 权限
export WISH_PACKAGE_PATH="$HOME/.wishtools/packages"
export WISH_STORAGE_PATH="$HOME/.wishtools/caches"
```

## 2. 命令范式：理解 Wish 的使用方式

Wish 的命令结构与传统包管理器完全不同。核心语法是：

```bash
wish <包列表...> - <要执行的命令>
```

这里的 `-` 是分隔符，左边是你需要的包，右边是你要运行的命令。

### 2.1 对比传统方式

| 传统方式 (pip/conda) | Wish 方式 |
| :--- | :--- |
| `pip install torch` <br> `python train.py` | `wish python pytorch - python train.py` |
| `conda activate myenv` <br> `jupyter notebook` | `wish python jupyter - jupyter notebook` |

**关键区别：**
*   无需预先安装或激活环境
*   环境是临时的、按需构建的
*   命令结束后环境自动释放，不污染系统

### 2.2 静默模式 vs 详细模式

```bash
# 静默模式 (用 - 分隔)：适合脚本和 CI
wish python=3.10 - python --version

# 详细模式 (用 + 分隔)：显示解析过程，适合调试
wish python=3.10 + python --version
```

## 3. 基础场景：运行 Python 脚本

最常见的用法是直接运行命令：

```bash
# 用 Python 3.10 运行脚本
$ wish python=3.10 - python train.py

# 用 Python + PyTorch 运行训练
$ wish python=3.10 pytorch=2.0 - python train.py

# 用多个包运行 Jupyter
$ wish python numpy pandas matplotlib - jupyter notebook
```

### 3.1 进入交互式 Shell

如果你需要在环境中做多次操作，**必须显式指定 shell 命令**（如 `bash`, `zsh` 或 `sh`）：

```bash
# 正确方式：显式启动 bash
$ wish python=3.10 - bash

# 环境已就绪（注意：提示符可能不会变化，取决于你的 shell 配置）
$ python --version
Python 3.10.6

$ which python
/home/user/.wishtools/packages/python/3.10.6.1.lin.0/bin/python

$ exit  # 退出子 shell 回到原环境
```

> **注意：** 如果不指定命令（如 `wish python=3.10`），Wish 将执行空操作并立即退出，**不会**自动进入 shell。

## 4. 进阶场景：解决依赖冲突

假设我们需要同时使用 `requests` 库和 `urllib3`，但 `requests` 对 `urllib3` 版本有要求。

```bash
# 故意制造一个潜在冲突：
# 请求 requests (依赖 urllib3<1.27) 和最新版 urllib3 (2.0+)
$ wish requests urllib3=2.0 - python -c "import requests"

[Solver] Resolving...
[Solver] Error: Conflict detected!
  - requests requires urllib3<1.27
  - User requested urllib3=2.0
  -> UNSATISFIABLE.
```

WISH 的 SAT 求解器会明确告诉你这**不可行**，而不是像 pip 那样可能默默安装不兼容的版本导致运行时报错。

**正确的做法**：让 Solver 自动计算。

```bash
$ wish requests - python -c "import requests; print(requests.__version__)"

[Solver] Solution:
  - requests: 2.28.1
  - urllib3: 1.26.9 (自动降级以满足依赖)
2.28.1
```

## 5. 复杂场景：混合语言开发栈

在游戏开发或 VFX 中，我们需要混合 Python 脚本和 C++ 编译工具。

```bash
# 一键构建 C++ 项目，无需手动配置工具链
$ wish cmake=3.20 gcc=9 boost=1.76 - cmake -B build && cmake --build build

# 在完整工具链下编译并测试
$ wish cmake=3.20 gcc=9 python=3.9 boost=1.76 - bash -c '
    cmake -B build
    cmake --build build
    python run_tests.py
'
```

注意：`LD_LIBRARY_PATH`、`PATH`、`PKG_CONFIG_PATH` 等都自动配置好了。

## 6. 离线模式实战 (Offline Mode)

Wish 的离线模式允许你在无网环境（如高安内网）中使用。

**场景**：你需要在一个无网服务器上运行 `python` 和 `numpy`。

1.  **准备阶段 (有网机器)**:
    ```bash
    # 仅仅下载包而不执行命令
    # 注意：这里我们使用 echo 来作为占位命令
    wish python numpy - echo "Downloading packages..."
    
    # 打包缓存目录
    tar -czf offline_cache.tar.gz -C ~/.wishtools/caches .
    ```

2.  **部署阶段 (无网机器)**:
    ```bash
    # 解压缓存
    mkdir -p ~/.wishtools/caches
    tar -xzf offline_cache.tar.gz -C ~/.wishtools/caches
    
    # 开启离线模式
    export WISH_OFFLINE_MODE=1
    
    # 正常运行
    wish python numpy - python script.py
    ```

## 7. 实用技巧补遗 (Pro Tips)

*   **缓存清理**: 定期运行 `rm -rf $WISH_STORAGE_PATH/*` 来释放磁盘空间（Wish 会自动重新下载需要的包）。
*   **别名魔法**: `alias wclean="rm -rf $WISH_STORAGE_PATH/*"`
*   **临时测试**: 使用 `export WISH_PACKAGE_EXTRA=debug-tools` 在不修改 package.py 的情况下注入调试工具。

## 8. 下一步

*   学习如何编写自己的包：[Package.py 编写指南](../advanced/package-guide.md)
*   了解背后的原理：[架构白皮书](../advanced/architecture.md)
