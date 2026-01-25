# API 参考手册

本文档详细介绍了 Wishtools 的核心类和 API 接口，适用于希望深入了解系统原理或进行二次开发的开发者。

## 1. 核心类概览

Wishtools 的核心逻辑通过以下继承链实现：

```
object
 └── Resolve (版本解析基类)
      └── Acquire (包获取类)
           └── Require (依赖处理入口)
```

**辅助组件：**
*   `Solver`: SAT 求解器 (pysat)
*   `Syncer`: 远程同步协调器 (High Availability)
*   `DBManage`: 缓存数据库管理 (SQLite)
*   `Locker`: 原子文件锁协调器

## 2. Resolve 类

**路径**: `wish/src/wishapi.py`

负责基础的版本解析、比较和区间计算逻辑。

### 核心方法

*   **`version_key(tags)`**: 将版本字符串转换为可比较的元组列表。
*   **`resolve_tags(flag, tags, tags_list)`**: 根据版本约束从列表中筛选符合条件的版本。
    *   **参数**: `flag` (运算符, 如 `">= "`), `tags` (目标版本), `tags_list` (候选版本列表)。
    *   **示例**: `resolve_tags(">=", "1.0", ["0.9", "1.0", "1.1"])` -> `["1.0", "1.1"]`
*   **`calculate_interval(int1, int2)`**: 计算两个版本区间的交集。这是版本求解的核心基础。

## 3. Acquire 类

**路径**: `wish/src/wishapi.py` (继承自 `Resolve`)

负责包的元数据获取、AST 解析和外部组件加载。

### 核心方法

*   **`resolve_platform(args)`**: 检查包是否满足当前的平台和架构约束。
    *   **逻辑**: 遍历 `ava` 列表，如果包含 `platform=xxx` 或 `arch=xxx`，则与 `Config.Platform` 进行比对。
*   **`parse_argv(path, argv, extend=True)`**: 解析 `package.py` 中的函数调用参数（使用 AST 静态分析，不执行代码）。
    *   **示例**: 提取 `req("python")` 中的 `"python"`。
*   **`resolve_cons(name, flag, tags, path)`**: 解析指定包的版本约束，返回符合条件的路径字典。

## 4. Require 类

**路径**: `wish/src/wishapi.py` (继承自 `Acquire`)

这是系统的主入口类，负责协调整个依赖解析和执行流程。

### 核心方法

*   **`process_pkgs(args)`**: 处理包列表的主逻辑。
    1.  调用 `resolve_pkgs` 递归构建依赖图。
    2.  调用 `Solver` 计算最优解。
    3.  处理 `pending` 状态的扩展包。
*   **`exec_reqs()`**: 按拓扑序（依赖顺序）执行已解析包的 `package.py`。这是环境生效的关键步骤。
    *   **机制**: 遍历 Solution 中的包，使用 `exec()` 函数在当前的 `this` 上下文中运行 `package.py` 内容。

## 5. Solver 类 (SAT 求解器)

**路径**: `wish/src/wishapi.py`

使用 `pysat` 库解决依赖冲突问题。核心思想是将依赖图转化为 CNF (合取范式) 公式，通过 MaxSAT 算法寻找权重最大的解。

### 核心方法

*   **`collect_solution(entry_names)`**: 收集满足所有约束的最优解。
    *   **策略**: 渐进式求解 (Top 5 -> Top 10 -> Full)。
*   **`collect_verbose_info(original_visited)`**: 在求解失败时，输出详细的诊断信息。
*   **`build_constraints(...)`**: 将依赖关系转换为 CNF 子句。
*   **`build_weights(...)`**: 计算每个版本变量的权重。公式：`(100 - pos) * 10000 + (100 - lvl) * 100 + rank`。

## 6. Syncer 类 (远程同步)

**路径**: `wish/src/wishapi.py`

协调本地缓存与远程仓库的同步，支持**高可用回退**机制。

### 核心方法

*   **`sync_pkgs(path)`**: 同步单个包（检查 ETag -> 下载 -> 解压 -> 更新 DB）。
*   **`first_api_client(method_name, *args)`**: 高可用 API 调用包装器。失败则依次轮询 `WISH_RESTAPI_URL1` 到 `WISH_RESTAPI_URL10`。

## 7. DBManage 类 (缓存管理)

**路径**: `wish/src/wishapi.py`

负责本地 SQLite 缓存的维护。

*   **`clean_cache(days=30)`**: 核心清理逻辑。
    *   **原理**: 遍历 `manifest` 表，找出 `last_access < (now - days)` 的记录。
    *   **策略 (LRU)**: 优先保留最近使用的包。这是在有限磁盘空间下维持高性能的关键。

## 8. Python API 集成示例 (Integration)

如果你需要在 Python 脚本中直接调用 Wish 的核心功能（而不是通过 CLI），可以参考以下示例。这对于开发自定义的管线工具非常有用。

### 示例：自动化查询依赖图

```python
import sys
import os

# 确保 wish 库在 PYTHONPATH 中
# 通常 wish 安装在 $WISH_LOCAL/wish/src
sys.path.append(os.getenv("WISH_LOCAL") + "/wish/src")

from wishapi import Require

def get_dependency_graph(packages):
    # 初始化核心类
    req_engine = Require()
    
    # 解析包列表 (模拟 wish cli 的输入)
    # process_pkgs 返回一个 Solution 字典
    solution = req_engine.process_pkgs(packages)
    
    if not solution:
        print("Failed to resolve dependencies.")
        return

    print(f"Resolved Solution for {packages}:")
    for pkg_name, version_info in solution.items():
        print(f"  - {pkg_name}: {version_info.tag}")

if __name__ == "__main__":
    # 查询 python=3.10 和 requests 的依赖树
    get_dependency_graph(["python=3.10", "requests"])
```

## 9. 错误代码与诊断 (Error Codes)

| 代码 | 名称 | 描述 | 潜在根因 |
| :--- | :--- | :--- | :--- |
| 1 | `NO_PARAM` | 未提供包名参数 | 用户输入为空 |
| 2 | `CONFIG_ERROR` | `package.py` 解析错误 | 语法错误、引用未导入模块 |
| 3 | `NETWORK_ERROR` | 网络连接失败 | DNS 故障、API 服务宕机、离线模式误触 |
| 4 | `SPECPATH_ERROR` | 指定的本地路径无效 | 路径拼写错误、缺少 `package.py` |
| 5 | `RESOLVE_ERROR` | 无法解析依赖 | 依赖冲突 (Ban)、版本不匹配、循环依赖 |
| 6 | `PENDING_ERROR` | 扩展包激活条件未满足 | `ext` 包的 `ava` 条件在当前上下文中为 False |
| 255 | `UNDEFINED` | 未定义错误 | 内部 Bug、未捕获的 Python 异常 |

## 10. 高级环境变量

*   `WISH_INHERIT_MODE`: 继承模式开关。设置为 "1" 时，子进程保留父进程环境。
*   `WISH_DEVELOP_MODE`: 启用开发模式。
*   `WISH_OFFLINE_MODE`: 强制离线模式。
*   `WISH_PACKAGE_EXTRA`: 强制启用特定的扩展包。
*   `WISH_RESTAPI_URL`: REST API 服务地址。
*   `WISH_STORAGE_URL`: S3/MinIO 存储服务地址。
