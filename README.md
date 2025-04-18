📦 Wish - 命令式依赖缓存执行器
Wish 是一个简洁高效的命令行工具，用于自动缓存你所需的包及其依赖，并立即执行指定命令，帮助你快速进入开发或运行环境 。

🚀 快速开始
安装
bash
复制编辑
cargo install wish

最小示例
bash
复制编辑
wish serde@./libs/serde=1.0.2 - echo "Hello with serde"


🧠 基本语法
命令格式如下：
bash
复制编辑
wish <包名>(必填)[@路径(可选)]=标签(可选) - 命令(可选)

@路径：指定包所在的本地路径；


=标签：指定版本选择规则；


- 命令：指定执行的命令，可省略；



🧰 版本选择规则
Wish 支持以下版本匹配语法：
符号
含义
示例
=
精确匹配最新次版本（默认）
serde=1 → 匹配 1.x 最新
<
小于某个版本
serde<1.3
>
大于某个版本
serde>1.0
<=
小于等于
serde<=1.2.0
>=
大于等于
serde>=1.0.1
==
精确指定版本
serde==1.0.2
!=
排除特定版本
serde!=1.0.71
+
输出详细执行信息（verbose 模式）
serde=1.0.2+


📂 本地路径与缓存机制
@路径 —— 仅支持本地路径
Wish 中的 @路径 用于指定包的本地来源路径，例如：
bash
复制编辑
wish mylib@./libs/mylib=0.2.0 - cargo test

⚠️ @路径 只支持本地路径，暂不支持 Git 或 URL 等远程源。

⚙️ 环境变量配置
Wish 提供以下环境变量用于控制缓存目录、同步模式及开发包路径：
环境变量
描述
默认值  
WISH_STORAGE_PATH
包缓存目录位置（可自定义）
当前安装目录下的相对路径
WISH_PKGSYNC_MODE
缓存同步模式：
0 = 使用缓存（默认）
1 = 不使用缓存（总是拉取）
2 = 使用开发路径
0
WISH_DEVELOP_PATH
指定开发路径（PKGSYNC_MODE=2 时使用）
安装目录下的 ./develops/

开发模式使用示例
bash
复制编辑
export WISH_PKGSYNC_MODE=2
export WISH_DEVELOP_PATH=./dev-packages

wish mypkg=0.2.1 - cargo run

此时 Wish 会从 ./dev-packages/mypkg/ 加载包内容。

💡 高级用法
同时加载多个包
bash
复制编辑
wish serde=1.0.2 tokio@./libs/tokio=1.35 - cargo build

仅缓存不执行
bash
复制编辑
wish anyhow=1.0.71


❓ 常见问题（FAQ）
Q: 可以不写 @路径 吗？
可以。如果不写，Wish 会使用默认的缓存路径或远程源。
Q: 命令必须要写吗？
命令可省略，仅用于缓存包及依赖。
Q: 如何开启 verbose 模式？
在版本号后添加 + 即可，如：serde=1.0.2 +

🤝 贡献指南
Fork 本项目；


创建 feature 分支；


提交 PR 并附上说明；


遵循简洁一致的文档格式；


