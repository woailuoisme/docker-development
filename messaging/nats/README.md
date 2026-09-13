# NATS + NUI

NATS 2.14（含 JetStream）与其管理界面 [NUI](https://github.com/nats-nui/nui)。

## 组件与端口

| 组件 | 容器名 | 容器内端口 | 宿主机端口 | 说明 |
|---|---|---|---|---|
| NATS | `nats` | 4222 / 8222 | 映射 4222、8222 | 客户端连接 / HTTP monitoring |
| NUI | `nui` | 31311 | **不映射** | 管理界面，仅由 Caddy 经 `frontend` 网络反代 |
| 一次性初始化 | `nui-context-init` | — | — | 从 `.env` 渲染 NUI 的 context 文件后退出 |

数据目录：`${DATA_PATH}nats`（JetStream store）、`${DATA_PATH}nui`（NUI 的 `/db`）、
`${DATA_PATH}nui-clicontexts`（NUI 的 `/clicontexts`，承载 init 容器渲染出的连接文件）。

## 访问入口

`https://nats.{$SITE_ADDRESS}` —— 经 Caddy 反代，**无任何鉴权**（`proxy-app`，不经 Authelia）。

> **这是明确接受的风险，不是疏漏。** NUI 自身没有任何登录机制，因此任何能解析该域名的人
> 都可以直接进入界面，并可通过 `GET /api/connection` 读到明文 NATS 凭据，
> 进而删流、发消息、管理 KV。
>
> 若将来要收紧，最小改动是把该行换回 `import proxy-app-auth ...`（Authelia 双因子），
> 或改用 `snippets/base-auth.conf`（HTTP Basic Auth，仓库已有该片段但当前未被任何规则使用，
> 需要额外声明 `BASIC_AUTH_USER` / `BASIC_AUTH_PASSWORD_HASH`）。

NUI **不发布宿主机端口**：宿主机端口会让流量绕过 Caddy（以及日后可能加上的任何网关侧鉴权），
且仓库内没有任何防火墙配置可依赖。若确需在宿主机直接访问，请用 SSH 端口转发，
而不是把 `ports` 加回来。

## 连接配置（声明式）

NUI **不读任何环境变量**、端口固定、`-db-path` 默认 `:memory:`（官方 entrypoint 已硬编码为 `/db`）。
它只认 `--nats-cli-contexts` 目录下的 `<名字>.json`。该契约已由源码（`pkg/clicontext/clicontext.go`）确认：

| 事实 | 结论 |
|---|---|
| 扫描方式 | 单层 `os.ReadDir`，**不递归子目录** |
| 文件匹配 | **只认 `.json`**（大小写敏感） |
| 连接名 | 文件名去掉 `.json`（`default.json` → 连接名 `default`） |
| **环境变量展开** | **完全不支持**——全包只有 `json.Unmarshal`，字段必须是明文 |

因此连接由 `nui-context-init`（`busybox`，一次性）从 `.env` 渲染出
`${DATA_PATH}nui-clicontexts/default.json`，`nui` 通过
`depends_on: condition: service_completed_successfully` 等它完成后再启动。
这样口令保持单一来源（`.env`），且 `data/nui` 被删也能复现连接。

> 渲染目标位于 `.gitignore` 的 `/data/` 下，**不进版本库**。

`nats` 服务本身不依赖该目录；`nui` 则必须等渲染完成，否则启动时导入不到 context。

### 该连接由文件管理，不要在 UI 里改它（已实测）

实测结论：NUI 每次启动都会重新导入 context 文件，且该导入是 **upsert**——
把文件里的密码改掉后仅重启 `nui`，已存连接立刻被文件值覆盖。
因此**文件管理的连接以文件为准**，在 UI 里对它的修改会在重启后丢失。

要改这条连接，请改 `.env` 或 `nui-context-init` 的渲染逻辑，而不是在 UI 里改。

NUI 会在连接上记录来源：`metadata.import-path` 与 `metadata.import-type: nats-cli`，
可用 `GET /api/connection` 查看，据此区分「文件管理」与「UI 创建」的连接。

## 口令与轮换

`NATS_USER` / `NATS_PASSWORD` 是**必需变量**：`docker-compose.yml` 刻意不提供兜底默认值。
原先是 `app` / `change-me-password`，会让弱口令静默生效；现在缺失时 compose 直接报错。

**轮换 `NATS_PASSWORD` 的完整步骤**（命令与顺序均经实测校准）：

1. 改 `.env` 的 `NATS_PASSWORD`
2. `docker compose up -d` —— 重建 `nats`（带走新口令），并**重跑** `nui-context-init` 重新渲染 `default.json`
3. **`docker compose restart nui`** —— 让 NUI 重新导入并覆盖那条连接

> 第 3 步必须用 `restart`：已实测 `up -d nui` **不会**重启 `nui`（它的配置没变），
> 因此不会重新导入，连接会一直用旧口令认证失败。
> 第 2 步已实测 `up -d` 会重跑已完成的 init 容器（`StartedAt` 会更新）。

## 已知风险（已接受，非疏漏）

- **`8222` monitoring 端口发布到 `0.0.0.0` 且无鉴权**：NATS 对 monitoring 端点没有内置鉴权，
  任何能到达该端口的人都能读取连接数、订阅关系与 JetStream 统计。该项经明确决策保持原状；
  若将来收紧，可从 `ports` 移除该行——NUI 与 NATS 同处 `backend` 网络，用 `nats:8222` 即可访问。
- **`4222` 客户端端口发布到 `0.0.0.0`**：受 `NATS_USER` / `NATS_PASSWORD` 保护，属于消息中间件的正常暴露方式。
- **`nats.{$SITE_ADDRESS}` 完全无鉴权，且 NUI 的 UI 与 API 均无认证、`GET /api/connection`
  会以明文返回连接密码**：该域名一旦可被解析，即等于公开 NATS 管理权与明文凭据。
  不发布宿主机端口只解决了「绕过网关直连」这一条路径，**不提供任何身份校验**。这是经明确决策接受的风险，详见「访问入口」。

## 当前无消费者

全仓库检索 `nats://`、`NATS_URL`、`NATS_TOKEN`、`nats-io` 均无命中——除本目录外没有服务连接 NATS。
因此本栈目前属于「已启用但无流量」，与 `database/pgbouncer` 的状态类似。
