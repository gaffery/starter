# CLI 参考手册

Wish 是一个高效的命令行依赖解析器和执行器。

## 命令格式

```shell
wish <package_names>[@path][=tag] [- command]
```

*   **package_names**: (必填) 请求的包列表。
*   **@path**: (可选) 指定用于调试的本地路径。
*   **=tag**: (可选) 版本约束。
*   **- command**: (可选) 环境设置完成后要执行的命令。

### 版本语法

| 语法 | 示例 | 含义 |
| :--- | :--- | :--- |
| `=` | `pkg=1.3` | 匹配最新的 `1.3.x` |
| `<` | `pkg<1.3` | 版本小于 `1.3` |
| `>` | `pkg>1.3` | 版本大于 `1.3` |
| `>=` | `pkg>=1.3` | 版本大于等于 `1.3` |
| `==` | `pkg==1.3` | 精确匹配 |
| `!=` | `pkg!=1.3` | 排除版本 |

### 执行模式

*   `-`: **简略模式 (Brief Mode)**。仅显示缓存信息。
*   `+`: **详细模式 (Verbose Mode)**。显示详细的执行日志和设置路径。

## 示例

**启动带 Requests 库的 Python 3.7**
```bash
wish python=3.7 requests - python
```

**复杂的版本约束**
```bash
wish python=3.10 requests>=2.32 - python
```

**调试模式 (显示详细日志)**
```bash
wish wish + start
```
输出解读:
```text
Setup Path: E:\WishTools\packages\idna\3.10.0\package.py
# ^ 指示当前加载了哪个包的定义文件

Relation Info:
... (JSON 结构的依赖图) ...
# ^ 显示 SAT 求解器的内部状态

Execution Time:
  Graph: 0.02s  (构建依赖图耗时)
  Solve: 0.05s  (求解耗时)
  Total: 0.10s
```

## 常用工具包 (如果安装了 search 包)

Wish 自身的设计哲学是"一切皆包"，因此 `search`、`info` 等功能通常也是作为包提供的。

**搜索包**
```bash
wish wish-search - search python
# 或者如果配置了别名
wish-search python
```

**查看包详情**
```bash
wish wish-info - info python
```
