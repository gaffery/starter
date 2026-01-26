# 最佳实践与设计模式

本文档汇总了在企业级环境中使用 WISH 的最佳实践、推荐的设计模式以及需要避免的反模式。

## 1. 命名与版本规范

### 1.1 版本号的解剖学

推荐使用 **语义化版本扩展格式**：`X.Y.Z.platform.build`

*   **X.Y.Z**: 上游软件的原始版本号 (如 Python 3.10.6)。
*   **platform**: 平台标识 (`lin`, `win`, `mac`)，用于快速区分。
*   **build**: 内部构建号 (0, 1, 2...)。当上游版本不变但包定义或编译选项变更时递增。

**示例**:
*   `3.10.6.lin.0`: Linux 版 Python 3.10.6，第 0 次构建。
*   `1.2.3.win.1`: Windows 版某库，第 1 次构建（可能修复了打包脚本）。

### 1.2 包名规范

*   使用 **小写字母** 和 **连字符**。
*   避免使用通用名称 (如 `utils`, `common`)，建议加前缀 (如 `company-utils`)。
*   **虚拟包**建议以 `-api` 或 `-interface` 结尾（非强制）。

## 2. 依赖设计模式

### 2.1 虚拟包模式 (The Virtual Package Pattern)

**场景**：你需要依赖一个功能（如 SSL 支持），但不关心具体是谁提供的（OpenSSL 1.1 还是 LibreSSL）。

**实现**：
```python
# package: openssl/1.1.1/package.py
alt("ssl-api")  # 我提供 ssl-api

# package: libressl/3.0.0/package.py
alt("ssl-api")  # 我也提供 ssl-api

# package: my-app/package.py
req("ssl-api")  # 我需要 ssl-api，谁来都行
```

### 2.2 互斥选择模式 (The Exclusive Choice Pattern)

**场景**：你的应用需要图形界面，支持 PyQt6 或 PySide6，但**绝不能同时加载两者**。

**实现**：
```python
# package: my-gui-tool/package.py
xor("PyQt6", "PySide6")
```

### 2.3 可选扩展模式 (The Optional Extension Pattern)

**场景**：你的工具主要功能不需要插件，但如果用户显式请求了插件，或者环境中恰好有这个插件，你需要加载它。

**实现**：
```python
# package: maya/2022/package.py

# 如果环境中存在 vray 且满足 platform=linux，则将 vray 纳入依赖计算
ext("vray@platform=linux")

# 如果用户设置了环境变量 WISH_PACKAGE_EXTRA=user-tools，则加载 user-tools
ext("user-tools")
```

### 2.4 插件注入模式 (The Plugin Injection Pattern)

**场景**：你需要为一个多宿主环境（如 VFX 流程中的 Maya, Nuke, Houdini）配置通用初始化脚本，但又不想让这个脚本强依赖所有宿主。

**实现**：
```python
# package: pipeline-init/1.0/package.py
req("requests", "shotgrid-api")

# 监听环境：如果环境中有 maya，就自动拉取 pipeline-init-maya 包
ext("pipeline-init-maya@maya")

# 如果环境中有 nuke，就自动拉取 pipeline-init-nuke 包
ext("pipeline-init-nuke@nuke")
```

## 3. 环境构建模式

### 3.1 代理模式 (The Proxy Pattern)

**场景**：统一管理系统级工具（如 gcc, make），直接使用宿主机版本但纳入 Wish 管理。

```python
# package.py
import os

system_gcc_path = "/usr/bin"
if os.path.exists(os.path.join(system_gcc_path, "gcc")):
    env("PATH").insert(system_gcc_path)
else:
    raise Exception("System gcc not found!")
```

### 3.2 动态适配器模式 (The Dynamic Adaptor)

**场景**：根据硬件特性（如 AVX2）自动加载优化库。

```python
# 纯 Python 逻辑，在执行阶段运行
import os

def has_avx2():
    # ...检测逻辑...
    return True

if has_avx2():
    env("LD_LIBRARY_PATH").insert(os.path.join(this.root, "lib", "avx2"))
else:
    env("LD_LIBRARY_PATH").insert(os.path.join(this.root, "lib", "std"))
```

### 3.3 首次初始化钩子 (First-Run Initialization)

**场景**：包安装后第一次运行时需要解压数据或编译缓存。

```python
if this.init:
    print(f"Initializing {this.name}...")
    # 解压大的资源文件
    os.system(f"tar -xf {this.root}/data.tar.gz -C {this.root}")
```

### 3.4 宿主伪装模式 (The Host Masquerade Pattern)

**场景**：你需要使用宿主机上已安装的庞大软件（如 Blender），但又想在 Wish 中像普通包一样依赖它。

**实现**：
```python
# package: blender-launcher/package.py
import os

alt("blender=5.0")

sys_path = r"C:\Program Files\Blender Foundation\Blender 5.0"

if os.path.exists(sys_path):
    env("PATH").insert(sys_path)
    alias("blender", "blender --python-use-system-env")
else:
    # 回退到 Wish 自举
    # 开启环境继承模式，防止插件环境丢失
    env("WISH_INHERIT_MODE").setenv("1")
    alias("blender", "wish blender=5.0 + blender")
```

## 4. 安全与成本 (Security & Cost)

### 4.1 安全最佳实践
*   **校验和验证**: 如果必须在运行时下载资源，务必校验 Hash。
*   **最小权限**: 不要在 `package.py` 中使用 `sudo`。
*   **CI/CD 安全**: 不要在 `package.py` 中硬编码 Token，应使用 `env("TOKEN").setenv(os.getenv("CI_TOKEN"))` 注入。

### 4.2 存储成本优化
*   **去重**: 对于大文件（如纹理库），建议将其打包为独立的 `asset-pack`，被多个软件版本共同依赖，而不是打进每个软件的 zip 包中。
*   **生命周期管理**: 在 S3 上配置 Lifecycle Rule，将超过 90 天未访问的 制品 (Artifact) (制品 (Artifact) (制品 (Artifact) (制品 (Artifacts)))) 转入 Cold Storage (Glacier)。

## 5. 仓库管理模式 (Repository Management)

### 5.1 单体仓库 vs 多仓库 (Monorepo vs Polyrepo)

对于 Wish 包的源码管理，有两种常见策略：

*   **Monorepo (推荐)**: 将所有内部包的 `package.py` 放在同一个 Git 仓库中。
    *   **优点**: 版本控制统一，方便进行大规模重构和依赖更新。`wish gitflow` 工具对 Monorepo 有很好的支持。
    *   **结构**: `wishtools-packages/packages/<pkg_name>/<version>/package.py`
*   **Polyrepo**: 每个包一个独立的 Git 仓库。
    *   **优点**: 权限控制更细粒度，适合开源或跨团队协作。
    *   **缺点**: 维护成本高，难以统一更新基础库依赖。

## 6. 包治理与生命周期 (Governance)

为了防止仓库膨胀，建议实施以下治理策略：

*   **废弃 (Deprecation)**: 在 `package.py` 中打印警告信息，提示用户该版本即将下线。
*   **日落 (Sunset)**: 将旧版本的 `ava()` 条件设置为 `False`，使其对所有新用户不可见，但保留文件以供旧工程回溯。
*   **归档 (Archival)**: 对超过 2 年无访问的包，从热存储移动到冷存储，并在图数据库中标记为 `ARCHIVED`。

## 7. 反模式 (Anti-Patterns)

### ❌ 上帝包 (The God Package)
**现象**：创建一个名为 `dev-env` 的包，`req()` 了 50 个其他包。
**问题**：导致依赖僵化，解析缓慢。
**修正**：使用**元包**拆分领域，如 `game-dev-set`, `web-dev-set`。

### ❌ 逻辑依赖陷阱 (The Logic-Dependency Trap)
**现象**：试图用 `if` 控制 `req()`。
```python
# 错误！！！
if sys.platform == "win32":
    req("win-lib")  # 静态解析器会无视 if，直接提取 req！
```
**修正**：使用 `ava("platform=windows")` 在 `win-lib` 包内部进行声明。

### ❌ 硬编码路径
**现象**：`env("PATH").insert("/opt/wish/packages/...")`
**修正**：永远使用 `this.root`。

## 8. 性能优化技巧

*   **Lazy Import**: 在 `package.py` 中，尽量把耗时的 import 放在函数内部。
*   **减少 I/O**: 避免在全局作用域进行文件读取。

## 9. 运维与使用技巧

### 9.1 不可变包策略
**原则**: 绝对不要手动修改 `packages/` 目录下的已安装文件。Wish 假设包是不可变的。如果需要调试，请使用 `WISH_DEVELOP_MODE=1`。

### 9.2 搜索空间优化
显式指定大版本 (如 `wish python=3`) 能显著减少 SAT 求解器 (Solver)的变量规模，提升解析速度。

### 9.3 缓存预热
在 CI/CD 流水线初始化阶段，可以预先运行一次全量同步命令 (`wish common-lib tools +`) 来消除运行时的下载等待。

## 10. CI/CD 集成模式 (CI/CD Integration Patterns)

### 10.1 GitLab CI 缓存策略
在 CI 环境中，每次都重新下载包会严重拖慢构建速度。建议缓存 `WISH_STORAGE_PATH`。

```yaml
# .gitlab-ci.yml 示例
variables:
  WISH_STORAGE_PATH: "$CI_PROJECT_DIR/.wish_cache"

cache:
  key: wish-cache
  paths:
    - .wish_cache/

build:
  script:
    - wish python cmake - python build.py
```

### 10.2 构建隔离
确保在 CI 中设置 `WISH_OFFLINE_MODE=0` 以允许下载，但可以通过 `WISH_PACKAGE_PATH` 隔离测试包和生产包。

### 10.3 容器化最佳实践 (Containerization)

当在 Docker 中运行 Wish 时：
1.  **分层构建**: 将基础包（如 Python, GCC）的安装放在 Dockerfile 的早期层，利用 Docker Layer Cache。
2.  **清理**: 在构建最终镜像时，删除 `$WISH_STORAGE_PATH/downloads` 目录，只保留解压后的 `packages` 目录，以减小镜像体积。
