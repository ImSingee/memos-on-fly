# 在 fly 上运行 memos

> 在 [fly.io](https://fly.io/) 上运行自托管的备忘录服务 [memos](https://github.com/usememos/memos)。使用 [litestream](https://litestream.io/) 将数据库自动备份到兼容 S3 的服务。

> **始终备份你的数据库。[在 fly.io 文档中阅读更多](https://fly.io/docs/reference/volumes/)。**

## 先决条件

  - [fly.io](https://fly.io/) 账户
  - [backblaze](https://www.backblaze.com/) 账户或其他兼容 S3 的服务账户 

## 安装 flyctl

1. 按照[说明](https://fly.io/docs/getting-started/installing-flyctl/)安装 fly 的 CLI `flyctl`。
2. [登录到 flyctl](https://fly.io/docs/getting-started/log-in-to-fly/) (`fly auth login`)。

## 下载配置文件

下载 [fly.example.toml](https://github.com/ImSingee/memos-on-fly/blob/master/fly.example.toml)，将其放到一个空目录并将文件重命名为 `fly.toml`。

在该目录内，运行 `fly launch` 并按照以下方式回答问题

```plaintext
An existing fly.toml file was found for app xxx-memos
? Would you like to copy its configuration to the new app? [选择 Yes]

Using build strategies '[the "ghcr.io/imsingee/memos-on-fly:latest" docker image]'. Remove [build] from fly.toml to force a rescan
? Choose an app name (leaving blank will default to 'xxx-memos') [输入你想设定的名字]

App will use 'hkg' region as primary
Created app 'xxx-memos' in organization 'personal'
Admin URL: https://fly.io/apps/xxx-memos
Hostname: xxx-memos.fly.dev

? Would you like to set up a Postgresql database now? [选择 No]

? Would you like to set up an Upstash Redis database now? [选择 No]

Wrote config file fly.toml
? Would you like to deploy now? [选择 No]

Platform: machines
✓ Configuration is valid
Your app is ready! Deploy with `flyctl deploy`
```

## 准备备份服务

> 如果你想使用其他存储提供商，请查看 litestream 的 ["Replica Guides"](https://litestream.io/guides/) 部分并根据需要调整配置

1. 登录到 B2 并[创建一个存储桶](https://litestream.io/guides/backblaze/#create-a-bucket)。我们将添加存储配置到 fly.toml，而不是直接调整 litestream 配置。
2. 现在你可以将 LITESTREAM_REPLICA_ENDPOINT 和 LITESTREAM_REPLICA_BUCKET 的值设置到你的`[env]` 部分。
3. 然后，为这个存储桶创建[一个访问密钥](https://litestream.io/guides/backblaze/#create-a-user)。将密钥添加到 fly 的秘密存储中（不要添加 `<` 和 `>`）。
    ```sh
    fly secrets set LITESTREAM_ACCESS_KEY_ID="<keyId>" LITESTREAM_SECRET_ACCESS_KEY="<applicationKey>"
    ```

## 部署

简单地运行 `fly deploy`。

如果一切正常，你现在可以通过运行 `fly open` 来访问 memos。你应该能看到 memos 的登录页面。

## （可选）自定义域名

 使用 `fly certs add <your domain>` 来配置自定义域名，并按照指示在你的 DNS 服务提供商处配置相关的域名解析（你可以在仪表板证书页面上检查域名配置状态）。

## 其他

### 如何更新到最新的 memos 版本

你可以简单地重新运行 `fly deploy`，fly.io 将拉取最新版本并升级到它。

> 在 memos 的 [官方发布](https://github.com/usememos/memos/releases) 之后，我们会自动触发一个镜像构建流程。你可以在[这里](https://github.com/ImSingee/memos-on-fly/pkgs/container/memos-on-fly)查看我们提供的确切版本。

### 验证安装

 - 你应该能够登录你的 memos 实例。
 - 你的 B2 存储桶中应该有一个初始的数据库副本。
 - VM 重启后，你的用户数据应该可以保留。 

#### 验证备份/扩展持久卷

Litestream 通过将其 [WAL](https://en.wikipedia.org/wiki/Write-ahead_logging) 持久化到 B2，每秒连续备份你的数据库。

有两种方式来验证这些备份：

 1. 在本地或第二个 VM 上运行 docker 镜像。验证数据库是否正确恢复。
 2. 用新的替换 fly 卷，并验证数据库是否正确恢复。

我们将重点关注 _2_，因为它模拟了实际的数据丢失情况。此过程也可用于将你的卷扩展到不同的大小。

首先手动备份你的数据：

 1. ssh 进入 VM 并将数据库复制到远程。如果只有你在使用你的实例，你也可以将书签导出为 HTML。
 2. 在 B2 管理面板中为 B2 存储桶创建一个快照。

现在列出所有 fly 卷并记下 `memos_data` 卷的 id。然后，删除该卷。

```sh
fly volumes list
fly volumes delete <id>
```

这将在几秒钟后导致一个**死亡**的 VM。创建一个新的 `memos_data` 卷。你的应用应该会自动尝试重启。如果没有，手动重启它。

当应用启动时，你应该能在日志中看到成功的恢复。

```
[info] 找不到数据库，尝试从副本恢复。
[info] 完成了数据库的恢复。
[info] 启动 litestream 和 memos 服务。
```

### 价格

假设一个 256MB 的 VM 和一个 3GB 的卷，此设置适用于 Fly 的免费层。[^0] B2 的备份也是免费的。[^1]

[^0]: 否则，VM 是每月约 $2。持久卷每 GB 每月 $0.15。
[^1]: 前 10GB 是免费的，然后每 GB $0.005。

## 故障排查

### litestream 记录 403 错误

检查你的 B2 密钥和环境变量是否正确。

### fly ssh 无法连接

检查 `fly doctor` 的输出，每一行都应该标记为 **PASSED**。如果 `Pinging WireGuard` 失败，尝试 `fly wireguard reset` 和 `fly agent restart`。

### fly 无法拉取 memos 的最新版本

只需运行 `fly deploy --no-cache`

## 感谢

[hu3rror/memos-on-fly](https://github.com/hu3rror/memos-on-fly)

