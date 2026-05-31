# Mosquitto Caddy 代理配置模块化设计方案

本文档定义了将 Caddy 网关中的 MQTT 代理配置（`mqtt.{$SITE_ADDRESS}`）从主配置文件（`Caddyfile`）中抽离，拆分为独立站点配置模块（`sites/mqtt.conf`）的设计规约。

---

## 1. 背景与目标

当前 `Caddyfile` 包含了对多个微服务以及基础组件的代理声明。随着我们添加了生产级的 Mosquitto 代理逻辑，主 `Caddyfile` 变得越发冗长，不利于未来的维护和扩展。

由于 Caddy 本身支持 `import sites/*` 模块化加载机制，将 MQTT 相关的反代规则拆分到独立的站点配置文件中，是遵循 Caddyfile 模块化管理的最佳实践。

---

## 2. 模块化设计

### 2.1 修改主配置文件 (Caddyfile)

*   **修改目标**：[Caddyfile](file:///Users/seaside/Projects/docker/development/caddy/Caddyfile)
*   **动作**：移除文件末尾用于定义 `mqtt.{$SITE_ADDRESS}` 的配置块（即原 Caddyfile 的第 62 行至 88 行部分）。

### 2.2 新建站点独立配置文件 (mqtt.conf)

*   **创建目标**：[mqtt.conf](file:///Users/seaside/Projects/docker/development/caddy/sites/mqtt.conf)
*   **动作**：在此文件中定义完整的 MQTT 代理服务规则。内容包含：
    *   引入请求日志、安全策略及 WAF snippet 模版。
    *   开启 `gzip` 和 `zstd` 压缩编码。
    *   独立拦截 `/health` 路径返回 `OK` 200 便于健康检测。
    *   将其余所有的长连接请求反向代理到内网 `mosquitto:9001`（WebSockets）端口，并配置好读写超时及响应非缓冲头以确保 WSS 长连接的稳定性。

---

## 3. 验证方案

1.  **Caddy 语法检验**：运行 `caddy validate` 校验合并和模块化载入后的全量配置，确保语法无误且服务能正确识别新载入的文件。
2.  **网络连通性测试**：使用 `curl` 请求 `https://mqtt.test.local/health`，验证站点能否正常响应 200 OK，证明 Caddy 正确加载了该域名并映射到此独立站点配置。
