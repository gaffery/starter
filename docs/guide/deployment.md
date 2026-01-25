# 部署与运维指南

本文档介绍 Wishtools 的部署配置、高可用设置、离线模式使用以及服务端搭建建议。

## 1. 客户端配置

### 1.1 目录规划

| 变量 | 默认值 | 建议路径 | 说明 |
| :--- | :--- | :--- | :--- |
| `WISH_LOCAL` | 脚本所在目录 | `/opt/wishtools` | 安装根目录 |
| `WISH_PACKAGE_PATH` | `$WISH_LOCAL/packages` | `/opt/wishtools/packages` | 共享包目录 |
| `WISH_STORAGE_PATH` | `~/.wishtools/caches` | `/var/cache/wish/storage` | 下载缓存 (建议大容量) |
| `WISH_DEVELOP_PATH` | `~/.wishtools/develops` | `~/wish-dev` | 个人开发包目录 |

### 1.2 环境变量配置

在 `/etc/profile.d/wish.sh` 或用户 `.bashrc` 中配置：

```bash
# 核心路径
export WISH_LOCAL="/opt/wishtools"
export PATH="$WISH_LOCAL:$PATH"

# 主仓库配置
export WISH_RESTAPI_URL="http://api.company.internal/graphs?access=KEY&secret=SEC"
export WISH_STORAGE_URL="http://s3.company.internal/bucket?access=KEY&secret=SEC"
```

### 1.3 高可用配置 (High Availability)

Wishtools 客户端支持自动故障转移。你可以在环境变量中配置多个备用节点（后缀 1-10）。

```bash
# 备用 API 节点 (当主节点不可达时尝试)
export WISH_RESTAPI_URL1="http://api-backup-1.company.internal/graphs?..."
export WISH_RESTAPI_URL2="http://api-backup-2.company.internal/graphs?..."

# 备用存储节点
export WISH_STORAGE_URL1="http://s3-backup-1.company.internal/bucket?..."
export WISH_STORAGE_URL2="http://s3-backup-2.company.internal/bucket?..."
```

系统会按顺序（无后缀 -> 1 -> 2 ... -> 10）轮询，直到连接成功。

## 2. 服务端部署架构 (Server-Side)

Wish 的后端架构基于经典的微服务设计，核心依赖于图数据库 (Graph DB) 和对象存储。

### 2.1 架构拓扑

```
[ Nginx Load Balancer ]
        |
        v
[ API Cluster (Python/FastAPI) ] <---> [ Redis Cache (Optional) ]
        |
        v
[ Graph Database (Neo4j) ]      [ Object Storage (S3/MinIO) ]
```

### 2.2 核心组件部署

#### 2.2.1 图数据库 (Neo4j)

Wish 强依赖图数据库来存储包的依赖关系与血缘图谱。
*   **推荐版本**: Neo4j 4.4 LTS 或 5.x

#### 2.2.2 元数据服务 (Wish API)

这是无状态的 Python 服务，建议通过 Docker 部署。

### 2.3 初始化流程

首次部署后，必须执行初始化脚本以建立图谱约束和索引：

```bash
# 1. 创建唯一性约束 (防止重复包名)
cypher-shell -u neo4j -p password "CREATE CONSTRAINT ON (p:Package) ASSERT p.name IS UNIQUE"

# 2. 创建版本索引 (加速解析)
cypher-shell -u neo4j -p password "CREATE INDEX ON :Version(tag)"
```

## 3. 容量规划与性能优化

### 3.1 API 服务规格
API 服务主要处理元数据查询，属于**计算密集型 + 读多写少**。
*   **小型团队 (10-50人)**: 2 CPU / 4GB RAM
*   **大型团队 (200+人)**: 8 CPU / 16GB RAM (建议集群部署)

### 3.2 S3 存储规格
存储服务处理大文件下载，属于**IO 密集型 + 带宽敏感**。
*   **带宽**: 建议内网带宽 > 10Gbps。对于跨国团队，强烈建议配置 CDN 或 S3 跨区域复制。

### 3.3 性能调优 (Performance Tuning)
*   **Neo4j**: 调整 `dbms.memory.heap.initial_size` 和 `dbms.memory.pagecache.size`。对于读密集型负载，Page Cache 应尽可能覆盖整个图数据文件。
*   **S3**: 启用 S3 Transfer Acceleration 或配置 CloudFront，以加速跨地域的大文件传输。

### 3.4 备份策略
*   **元数据 (Graph DB)**: 每日全量 + 实时 Binlog。
*   **包文件 (S3 Objects)**: 开启版本控制 + 跨区域复制 (CRR)。

## 4. 全球多地协同架构

对于跨国团队（如上海、伦敦、洛杉矶），推荐采用**主备复制架构**。

### 4.1 架构拓扑

```
[Master Region: Shanghai]
    ├── REST API (Master DB)  <--- 所有元数据写入
    └── S3 Bucket (Master)    <--- 所有包文件上传
           │
           │ (S3 Cross-Region Replication)
           ▼
[Slave Region: Los Angeles]
    └── S3 Bucket (Slave)     <--- 只读镜像
```

### 4.2 客户端配置策略

利用 WISH 的多源回退机制，让不同地区的客户端优先连接本地节点。例如洛杉矶办公室配置本地 S3 镜像为 `WISH_STORAGE_URL`，上海主节点为 `WISH_STORAGE_URL1`。

## 5. 离线模式部署

在无法连接外网或内网服务器的隔离环境中使用 Wishtools。

1.  **准备离线包**: 在有网环境下载包并打包 `packages` 目录。
2.  **配置**: 设置 `export WISH_OFFLINE_MODE=1`。

启用离线模式后，Wish 将不再尝试连接 API，仅使用本地 `WISH_PACKAGE_PATH` 中的包。

## 6. 安全加固

*   **API 安全**: 建议在 Nginx/Kong 网关层做 Basic Auth 或 IP 白名单。
*   **S3 安全**: 配置 IAM Policy，允许 `GetObject` 但禁止 `PutObject`（仅 CI/CD 账号有写权限）。

## 7. 部署前检查清单 (Pre-flight Checklist)

在正式上线前，请确认以下事项：

- [ ] **域名解析**: 确认 `WISH_RESTAPI_URL` 和 `WISH_STORAGE_URL` 的 DNS 解析正确。
- [ ] **连通性测试**: 在客户端运行 `curl -I $WISH_RESTAPI_URL` 确保 HTTP 200/404 (非 5xx)。
- [ ] **存储权限**: 尝试手动上传一个小文件到 S3 Bucket 验证写权限。
- [ ] **索引构建**: 确认 Neo4j 中的索引已建立 (使用 `:schema` 命令查看)。
- [ ] **客户端版本**: 确认所有客户端使用的是统一的 Wish 脚本版本。

## 8. 灾难恢复 (Disaster Recovery)

为防止意外数据丢失，应制定完善的 DR 计划：

*   **元数据快照**: 每天凌晨自动运行 `neo4j-admin dump` 并上传至异地 S3。
*   **包文件一致性**: 启用 S3 的 Versioning 功能，防止误删或覆盖。
*   **恢复演练**: 每季度进行一次从零恢复演练，验证备份文件的可用性。

## 9. 监控与告警 (Monitoring & Observability)

为了确保企业级稳定性，建议接入监控系统：

*   **API 监控**: 监控 HTTP 状态码分布（关注 5xx 比例）和 P99 延迟。
*   **图数据库监控**: 监控 Neo4j 的 Page Cache Hit Ratio 和 GC 频率。
*   **客户端遥测**: 利用 Telemetry Hub 收集的客户端错误日志配置实时告警（如大规模解析失败）。
