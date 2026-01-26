# 常见问题解答 (FAQ)

本页汇集了关于 Wish Platform 的高频问题，涵盖了从基础使用到深入调试的各个方面。

### 环境与执行

**Q: 我可以省略 `@path` 吗？**
A: 可以。Wish 将使用默认缓存或远程源。

**Q: `- command` 部分是必须的吗？**
A: 不是。如果省略，Wish 将仅解析并缓存环境，不执行任何命令。这通常用于预热缓存。

**Q: Launcher 提示权限被拒绝 (permission denied)？**
A:
*   **Windows**: 请右键以管理员身份运行。
*   **Linux**: 运行 `chmod +x platforms/linux/launcher` 赋予执行权限。

**Q: 找不到 wish 命令 (command not found)？**
A: 请确保包含 `wish` 的目录已添加到您的 `PATH` 环境变量中。参考 [快速上手指南](../guide/quick-start.md#12-shell-集成-shell-integration)。

### 缓存与依赖

**Q: 如何清除缓存？**
A: 删除 `caches/` 目录。Wish 将在下次运行时重新拉取所有必要的包。
注意：这将删除所有已下载的包文件，下次运行可能会比较慢。

**Q: 如何处理依赖冲突？**
A: Wish 的 SAT 求解器 (Solver)会自动处理大多数冲突。如果遇到 `UNSATISFIABLE` 错误，说明当前的约束条件在数学上无解。
解决方法：
1.  **放宽约束**: 尝试使用更宽松的版本号 (如 `pkg>=1.0` 而不是 `pkg==1.2.3`)。
2.  **显式排除**: 在 `package.py` 中使用 `ban("conflicting-pkg")`。
3.  **锁定版本**: 在命令行显式指定关键包的版本 (如 `wish python=3.10 ...`)，这会提高该版本的权重。

**Q: Wish 支持 Lockfile 吗？**
A: Wish 不使用传统的 lockfile。它的哲学是"确定性解析"。只要输入的约束条件不变，且远程仓库不可变，解析结果就是确定性的。
如果需要严格锁定，建议导出解析后的完整包列表并在生产环境中使用。

### 高级功能

**Q: 并发下载时会发生什么？**
A: Wish 使用原子文件锁 (`.lock` 文件) 来协调多进程并发。如果多个 Wish 进程试图下载同一个包，第一个进程会获得锁进行下载，其他进程会等待直到锁释放。详情请见 [架构设计细节](../advanced/implementation.md#84-并发控制机制-locking-mechanism)。

**Q: 什么是"环境继承模式"？**
A: 默认情况下，Wish 会清洗掉可能污染环境的变量 (如 `PYTHONPATH`)。如果你想保留父 Shell 的环境，可以设置 `export WISH_INHERIT_MODE=1`。这在某些系统集成场景下很有用，但可能会降低可重现性。

### 性能与优化 (Performance)

**Q: 为什么 Wish 第一次启动很慢？**
A: 第一次启动需要下载元数据和包文件。后续启动会使用本地缓存，通常在 50ms-200ms 内完成。

**Q: 如何加速下载？**
A: 建议在公司内部部署私有 S3 镜像源，并配置 `WISH_STORAGE_URL` 指向该内网地址。

### 服务端与贡献

**Q: 后端是如何部署的？**
A: Wish 采用联邦式架构。元数据存储在图数据库 (Neo4j) 中，而实际的大文件存储在对象存储 (MinIO/S3) 中。详情请见 [架构设计](../advanced/architecture.md)。

**Q: 如何贡献一个包？**
A: 请遵循 [包开发指南](../advanced/package-guide.md)，创建一个 `package.py`，然后通过 `wish gitflow` 工具推送。
