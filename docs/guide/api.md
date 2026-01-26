# API 参考手册

本文档详细介绍了 Wish Platform 的核心类和 API 接口，适用于希望深入了解系统原理或进行二次开发的开发者。

## 1. 核心类概览

Wish Platform 的核心逻辑通过以下继承链实现：

```text
object
 └── Resolve (版本解析基类)
      └── Acquire (包获取类)
           └── Require (依赖处理入口)
```

### 1.1 主要组件
*   **求解器 (Solver)**: 基于 MaxSAT 算法解决版本冲突。
*   **同步器 (Syncer)**: 处理本地与远程存储的文件同步。
*   **环境管理器 (Environ)**: 动态管理当前进程的环境变量（内存级）。

## 2. Resolve 类 (核心算法)

负责语义化版本解析与区间计算。

### `version_key(tag: str) -> list`
将版本字符串（如 `3.10.6.lin.0`）拆分为可比较的元组。

### `calculate_interval(int1, int2) -> Interval`
计算两个版本区间的交集。这是依赖解析的核心。

## 3. Syncer 类 (远程同步)

### `sync_pkgs(path: str) -> bool`
同步本地缓存与远程仓库。检查 ETag，如不一致则启动分块下载与解压。

### `first_api_client(method_name: str, *args)` (高可用机制)
**高可用 (HA) 核心**: 当主 `WISH_RESTAPI_URL` 连接失败时，会自动尝试从 `WISH_RESTAPI_URL1` 轮询到 `WISH_RESTAPI_URL10`。

## 4. 求解器 (Solver) 类

### `collect_solution(entry_names: list) -> dict`
收集满足所有硬约束的权重最大解。
- **策略**: 渐进式求解（Top 5 -> Top 10 -> Full）。

### `build_constraints(visited_nodes: list)`
将依赖关系图（Nodes/Edges）转换为 SAT 求解器 (Solver)所需的 CNF 子句。

## 5. Require 类 (入口)

### `process_pkgs(pkgs: list) -> dict`
Wish 的主入口函数。
- **流程**: 递归解析依赖 -> 调用求解器 (Solver) -> 返回最优解。

### `exec_reqs()`
按拓扑序执行所有选中包的 `package.py`。

## 6. DBManage (Cache Pruning)

### `prune_cache(days: int)`
**缓存清理 (Cache Pruning)**: 扫描 `WISH_STORAGE_PATH`，根据遥测数据和最后访问时间，自动清理超过 `days` 天未使用的制品 (Artifact)。

## 7. 开发示例

### 场景 A：在 Python 脚本中自动化解析环境

```python
from wishapi import Require

req = Require()
# 仅仅解析 python 3.10 环境
solution = req.process_pkgs(["python=3.10"])

for name, ver in solution.items():
    print(f"选中制品 (Artifact): {name} -> {ver.tag}")
```

### 场景 B：Python 集成示例 (Python Integration Example)
通过 Python 脚本动态启动一个配置好的子进程环境：

```python
import subprocess
from wishapi import Require, Environ

# 1. 解析依赖
req = Require()
solution = req.process_pkgs(["maya=2024", "mtoa"])

# 2. 构建环境
env_manager = Environ()
env_dict = env_manager.build_env_dict(solution)

# 3. 启动集成脚本
subprocess.run(["maya", "-script", "render.py"], env=env_dict)
```
