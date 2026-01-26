# 依赖解析核心原理 (Core Dependency Resolution)

本文档是 Wish 依赖管理系统的核心技术白皮书，涵盖了从**版本定义**到**冲突求解**的完整技术链路。

## 第一部分：版本约束系统 (The Constraints)

在求解之前，系统必须先理解什么是"版本"以及如何比较它们。

### 1. 核心算法：version_key

Wish Platform 不仅仅比较字符串，而是将版本号解析为**语义元组序列**。

#### 1.1 解析规则

算法将版本字符串切分为**数字部分**和**非数字部分**。

```python
def version_key(tags):
    parts = []
    current_num = ""
    current_str = ""
    for char in tags:
        if char.isdigit():
            parts.append((1, int(current_num))) 
        else:
            parts.append((0, current_str))
    return parts
```

#### 1.2 比较示例

| 版本 A | 版本 B | 比较结果 | 原因 |
| :--- | :--- | :--- | :--- |
| `1.2` | `1.10` | A < B | 数字比较: 2 < 10 |
| `1.0` | `1.0.0` | A < B | 元组长度: (1,0) < (1,0,1,0) |
| `3.10.6` | `3.10.6.lin.0` | A < B | 构建号优先: 无构建号 < 有构建号 |

### 2. 七种运算符详解

| 运算符 | 逻辑 | 数学区间 | 示例 |
| :--- | :--- | :--- | :--- |
| `=` | **前缀包含** | $[v, v_{next})$ | `lib=1.0` (包含 1.0.0 到 1.0.99) |
| `==` | **绝对相等** | $[v, v]$ | `lib==1.0.0` (仅匹配 1.0.0) |
| `>=` | **左闭区间** | $[v, \infty)$ | `lib>=2.0` |
| `>` | **左开区间** | $(v, \infty)$ | `lib>2.0` |
| `<=` | **右闭区间** | $(-\infty, v]$ | `lib<=2.0` |
| `<` | **右开区间** | $(-\infty, v)$ | `lib<2.0` |
| `!=` | **不等于** | $(-\infty, v) \cup (v, \infty)$ | `lib!=1.0` |

## 第二部分：SAT 求解逻辑 (求解器 (Solver))

一旦所有的包版本被识别和排序，WISH 将依赖解析问题转换为加权最大可满足性问题 (Weighted Partial MaxSAT)。

### 1. SAT 问题建模

#### 1.1 变量映射 (Variable Mapping)

求解器 (Solver)将每个 `(Package, Version)` 对映射为一个唯一的整数 ID（布尔变量）。

```python
{
    ('python', '3.9.1'): 1,
    ('python', '3.10.0'): 2,
    ('numpy', '1.21.0'): 3,
    ('numpy', '1.24.0'): 4,
    ...
}
```

#### 1.2 硬约束 (Hard Constraints)

硬约束是必须满足的条件，转换为 CNF 子句。如果无法满足，求解器 (Solver)返回 UNSAT（无解）。

1.  **单版本互斥 (Single Version Selection)**:
    对于同一个包，不能同时选择两个版本。
    `[-1, -2]`  => (NOT python@3.9.1) OR (NOT python@3.10.0)

2.  **必需依赖 (Require)**:
    如果选择了 `numpy@1.24.0` (ID: 4)，且它依赖 `python>=3.9` (ID: 1, 2)，则必须选择 ID 1 或 2 中的一个。
    `[-4, 1, 2]` => (NOT numpy@1.24.0) OR (python@3.9.1) OR (python@3.10.0)

3.  **冲突禁止 (Ban)**:
    如果选择了包 A (ID: 10)，且它 `ban("B")` (ID: 20)，则两者不能共存。
    `[-10, -20]`

4.  **入口包存在 (Entry Existence)**:
    用户请求的包必须至少选中一个版本。
    `[1, 2]` => python@3.9.1 OR python@3.10.0

#### 1.3 软约束与权重 (Soft Constraints & Weights)

当存在多个满足硬约束的解时，求解器 (Solver)通过最大化权重和来选择"最优"解。

**权重计算公式**:
```python
Weight = (100 - Pos) * 10000 + (100 - Level) * 100 + Rank
```

*   **Pos (Position)**: 命令行参数中的位置索引 (0, 1, 2...)。用户显式指定的包优先级最高。
*   **Level (Depth)**: BFS 依赖树的深度。浅层依赖优先于深层依赖。
*   **Rank (Version Index)**: 版本排序索引 (0=最旧, N=最新)。新版本优先。

### 2. 权重计算仿真 (Simulation)

假设用户执行 `wish python requests`。

**场景**:
*   `python` 有版本 `3.9` (Rank 0), `3.10` (Rank 1)。
*   `requests` 有版本 `2.0` (Rank 0)。
*   `requests` 依赖 `urllib3`。

**计算过程**:

1.  **Python (Pos=0, Level=0)**
    *   `python@3.9`: `(100-0)*10000 + (100-0)*100 + 0` = **1010000**
    *   `python@3.10`: `(100-0)*10000 + (100-0)*100 + 1` = **1010001** (胜出)

2.  **Requests (Pos=1, Level=0)**
    *   `requests@2.0`: `(100-1)*10000 + (100-0)*100 + 0` = **1000000**

3.  **Urllib3 (Pos=N/A, Level=1)** (作为 requests 的依赖)
    *   `urllib3@1.0`: `(100-N/A)*0 + (100-1)*100 + 0` = **9900** (注: 非入口包 Pos 项为 0)

**结论**:
系统会绝对优先满足 `python` 的版本需求（权重级 101w），其次是 `requests`（权重级 100w）。即使 `urllib3` 有一个新版本能极大增加总权重，只要它导致 `python` 或 `requests` 无法选到最新版（例如产生了冲突），求解器 (Solver)也会放弃它。

### 3. 钻石依赖冲突解析 (Diamond Dependency Example)

**场景**:
*   `App` 依赖 `LibA` 和 `LibB`。
*   `LibA` 依赖 `Core=1.0`。
*   `LibB` 依赖 `Core=2.0`。

这是一个经典的钻石依赖冲突。在 SAT 模型中，这表现为：
1.  选中 `App` => 选中 `LibA` AND `LibB`。
2.  选中 `LibA` => 选中 `Core@1.0`。
3.  选中 `LibB` => 选中 `Core@2.0`。
4.  硬约束：`Core@1.0` 和 `Core@2.0` 互斥 (不能同时选中)。

结果：**UNSATISFIABLE** (无解)。
SAT 求解器 (Solver)会迅速检测到这种逻辑矛盾，并报告冲突路径，而不是像某些包管理器那样陷入无限循环或随机选择一个版本。

### 4. 渐进式求解策略 (Progressive Solving)

为了提高性能，`求解器 (Solver).collect_solution` 采用分阶段策略：

1.  **Phase 1 (Top 5)**: 仅加载每个包最新的 5 个版本尝试求解。
2.  **Phase 2 (Top 10)**: 如果 Phase 1 失败，扩大范围至最新的 10 个版本。
3.  **Phase 3 (Top 20...50)**: 逐步扩大搜索空间。
4.  **Phase 4 (Full)**: 加载所有已知版本进行最终尝试。

这种策略显著降低了平均解析时间，同时保留了在复杂冲突场景下找到解的能力。

### 5. 诊断日志解读

当使用 `wish +` (Verbose Mode) 时，如果求解失败，求解器 (Solver) 会输出详细的诊断信息。

```
[Relation and Error Info]
{
  ('python', '3.10.0'): {
    'req': ['openssl>=1.1'],
    'error': {
      'missing': ['openssl']  <-- 关键信息：找不到满足 openssl>=1.1 的包
    }
  }
}
```

*   **req**: 该版本声明的依赖。
*   **error**:
    *   `missing`: 依赖包缺失或版本不匹配。
    *   `conflict`: 触发了 `ban` 规则。
    *   `unavailable`: `ava` 条件未满足。

### 6. 深度解析：为什么选择 SAT？

1.  **算法复杂度**: 传统的贪心或回溯算法在面对复杂的依赖关系（如 "钻石依赖"）时，时间复杂度可能是指数级的。SAT 求解器 (Solver)能极其高效地处理成千上万个变量的约束。
2.  **全局最优保证**: MaxSAT 算法保证在所有可行解中找到权重和最大的那个，即全局最优解。
3.  **性能表现**: 对于典型的软件栈（<500 个包），Wish 的解析时间通常稳定在 **10-50ms** 级别。
