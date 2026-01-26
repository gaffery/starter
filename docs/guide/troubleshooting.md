# 故障排查与诊断指南

本文档旨在帮助开发者和运维人员快速定位和解决 Wish Platform 运行过程中的常见问题。

## 1. 核心流程诊断

### 1.1 解析阶段故障 (Resolution Phase)

**症状**: 报错 `RESOLVE_ERROR`，提示 "Cannot resolve conditions"。

**诊断日志示例**:
当开启详细模式 (`+`) 时，求解器 (Solver) 会输出冲突信息：
```json
[Relation and Error Info]
{
  ("maya", "2024"): {
    "req": ["python==3.10"],
    "error": {
      "conflict": ["python==3.7 (Required by user)"]
    }
  }
}
```
**解读**: 该日志显示用户手动指定了 `python==3.7`，但 `maya=2024` 强制要求 `python==3.10`，导致版本冲突。

### 1.2 性能分析 (Performance Profiling)
如果环境启动缓慢，需要区分瓶颈所在：
*   **图构建时间 (Graph Time)**: 扫描 `package.py` 并构建依赖图的时间。如果过长，说明本地缓存的包数量过多或磁盘 IO 慢。
*   **求解时间 (Solve Time)**: SAT 求解器 (Solver) 计算最优解的时间。如果过长，说明依赖关系过于复杂，存在大量可选路径。
*   **下载/解压时间**: 网络带宽或磁盘写入瓶颈。

使用 `wish --profile <pkg>` 可以输出详细的时间分布报告。

### 1.3 UNSAT Core 调试指南
当依赖关系彻底无解时，Wish 会尝试提取 **UNSAT Core**（导致无解的最小冲突集合）：
1.  运行 `wish <pkg> --debug-unsat`。
2.  系统会输出类似 `Conflict: [A->B, B->C, C->!A]` 的逻辑链。
3.  **操作**: 必须打破链条中的至少一个环节（例如放宽 C 对 A 的冲突限制）。

### 1.4 循环依赖 (Circular Dependency)

**识别**: 报错信息显示 `Recursion depth exceeded` 或依赖链中出现重复节点（如 A -> B -> A）。

**解决方案**:
1.  **打破闭环**: 检查最近修改的 `package.py`，确保依赖不是相互包含。
2.  **抽象解耦**: 将 A 和 B 共同依赖的逻辑提取到独立的 C 包中，让 A 和 B 都依赖 C。

## 2. 常见错误代码 (Error Codes)

| 代码 | 名称 | 描述 | 建议操作 |
| :--- | :--- | :--- | :--- |
| 1 | `NO_PARAM` | 未提供参数 | 检查命令格式 |
| 2 | `CONFIG_ERROR` | package.py 语法错误 | 使用详细模式查看 Traceback |
| 3 | `NETWORK_ERROR` | 连接 API/S3 失败 | 检查网络、代理及 HA 节点配置 |
| 5 | `RESOLVE_ERROR` | 依赖关系无解 | 分析冲突日志，放宽版本约束 |

## 3. 运维诊断

### 3.1 下载锁残留
**故障**: 提示 "Waiting for locker..." 且长时间无反应。
**解决**: 检查并删除 `$WISH_STORAGE_PATH` 下的 `.lock` 文件：
```bash
find $WISH_STORAGE_PATH -name "*.lock" -delete
```

### 3.2 环境变量污染
**现象**: 启动的环境中包含不属于该包的旧变量。
**解决**: 启用 **继承清洗模式** 或显式调用 `env().unload()`。
