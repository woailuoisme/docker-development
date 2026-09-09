# Nginx 全功能模块化网关 (High-Performance Gateway)

基于 `nginx:1.31-trixie` 深度定制的开发/生产全功能网络网关。采用 **Dockerfile 一体化镜像内嵌** 与 **模块化片段设计**，实现开箱即用、零配置启动闪退崩溃防护、毫秒级动态上游解析与 Docker 原生健康检查。

---

## 🏗️ 架构与流量流向拓扑

```text
[ 客户端请求 (HTTP 80 / HTTPS 443 / WSS 8080) ]
                      │
                      ▼
[ Docker Nginx 网关 (基于 Dockerfile 一体化集成) ]
    ├── 启动期探针: 05-init-ssl.sh (自签通配符证书兜底)
    ├── 启动期渲染: 20-envsubst (将 templates/ 渲染为 conf.d/*.conf)
    ├── 核心安全层: anti-ddos.conf (限流防刷) + waf.conf (SQLi/XSS拦截)
    ├── 传输优化层: compression.conf (Gzip压缩) + http2 on + ssl.conf
    └── 日志审计层: logging.conf (结构化输出至 stdout/stderr)
                      │
                      ▼ 运行时 Docker DNS 动态解析 (resolver 127.0.0.11)
        ┌─────────────┼─────────────┬─────────────┐
        ▼             ▼             ▼             ▼
   [PHP-FPM]     [API微服务]   [前端SPA静态]  [Node SSR/Vite]
   (Laravel)      (REST/SSE/WS)  (React/Vue)  (Next/Nuxt/HMR)
```

---

## 📁 目录组织规范

```text
gateways/nginx/
├── Dockerfile                    # 一体化镜像构建定义 (内嵌配置与安全探针)
├── docker-compose.yml            # 极简编排定义 (仅挂载业务代码与持久化证书)
├── nginx.conf                    # 全局主配置文件 (优化 worker_connections 与文件描述符)
├── entrypoint.d/
│   └── 05-init-ssl.sh            # 启动前自签通配符证书兜底脚本 (防首次启动崩溃)
├── snippets/                     # 模块化高内聚功能片段
│   ├── anti-ddos.conf            # 请求频率与连接并发限流
│   ├── base-auth.conf            # HTTP Basic Auth 快速认证
│   ├── compression.conf          # Gzip 高性能压缩策略
│   ├── fastcgi-security.conf     # PHP-FPM 上传目录脚本执行拦截
│   ├── http-core.conf            # 字符集、缓冲区、Docker DNS 解析器
│   ├── logging.conf              # 结构化访问与错误日志格式
│   ├── proxy.conf                # 标准反代 Header、WebSocket 升级与超时
│   ├── security-headers.conf     # HSTS, X-Frame-Options, CSP 等安全响应头
│   ├── ssl.conf                  # TLS 1.2/1.3 现代安全加密套件与 Session 缓存
│   ├── stream.conf               # TCP/UDP 四层流量代理片段 (按需启用)
│   └── waf.conf                  # 基础 SQLi、目录穿越、敏感文件拦截
└── templates/                    # 开箱即用站点模板 (由 envsubst 自动生成 .conf)
    ├── default.conf.template     # 默认黑洞兜底 (444 阻断未授权 IP 扫描) + /healthz
    ├── fpm.conf.template         # Laravel / Symfony 等现代 PHP-FPM 生产模板
    ├── proxy.conf.template       # REST API / SSE 流式推送 / WebSocket / Dozzle 日志全能反代
    ├── spa.conf.template         # React / Vue / Vite 静态打包产物单页托管
    └── ssr.conf.template         # Next.js / Nuxt / Vite 开发容器 (支持流式渲染与 HMR)
```

---

## 🚀 内置核心模板与特性 (Templates)

所有模板文件存放在 `templates/` 目录，容器启动时自动识别并渲染为 `/etc/nginx/conf.d/*.conf`：

| 模板文件 | 访问子域名 | 适用场景与核心技术亮点 |
| :--- | :--- | :--- |
| **`default.conf.template`** | `_` (所有未匹配域名) | **安全黑洞兜底**：直接返回 `444` 丢弃恶意 IP 扫描流量；内置 `/healthz` 存活路由供 Docker/K8s 探针检测。 |
| **`fpm.conf.template`** | `app.${SITE_ADDRESS}` | **Laravel / PHP-FPM 应用**：自动强制跳转 HTTPS，内置 URL 重写，采用动态变量解析（`set $php_fpm_backend`），**PHP 容器未启动时 Nginx 也绝不崩溃**。 |
| **`proxy.conf.template`** | `api.${SITE_ADDRESS}` | **全功能反向代理**：关闭缓冲区（`proxy_buffering off`），配置 24 小时超长超时，完美支持 **AI Chat 流式打字机 (SSE)**、**WebSocket** 与实时日志流（Dozzle）。 |
| **`spa.conf.template`** | `web.${SITE_ADDRESS}` | **现代单页打包托管**：托管 `dist/` 产物，带 Hash 静态资源开启 1 年强缓存，`index.html` 禁用缓存保证即时发版生效，内置 `/api/` 转发。 |
| **`ssr.conf.template`** | `node.${SITE_ADDRESS}` | **服务端渲染与开发服务器**：适配 Next.js / Nuxt 流式 SSR 输出，全面支持 Vite 开发容器的 HMR WebSocket 热重载长连接。 |

---

## ⚙️ 环境变量配置 (Environment Variables)

在项目根目录 `.env` 中按需配置：

```dotenv
# 基础域名
SITE_ADDRESS=test.local

# 上游服务地址与端口 (HOST:PORT 一体化)
PHP_UPSTREAM=php-fpm:9000
API_UPSTREAM=api:8080
FRONTEND_UPSTREAM=frontend:3000

# 外部暴露端口映射
NGINX_HOST_HTTP_PORT=80
NGINX_HOST_HTTPS_PORT=443
NGINX_HOST_WSS_PORT=8080

# 时区
TIMEZONE=Asia/Shanghai
```

---

## 🛠️ 常用运维命令 (Commands)

### 1. 启用与启动 Nginx

若要使用 Nginx 代替 Caddy 作为主网关，请在 `gateways/docker-compose.yml` 中取消注释 `- nginx/docker-compose.yml`，然后执行：

```bash
# 构建并后台启动 Nginx 网关
docker compose up -d --build nginx

# 重启 Nginx
docker compose restart nginx

# 停止服务
docker compose stop nginx
```

### 2. 配置自检与热重载 (Zero-Downtime Reload)

```bash
# 1. 在容器内测试当前渲染后的配置文件语法
docker compose exec nginx nginx -t

# 2. 不中断连接平滑热重载配置
docker compose exec nginx nginx -s reload
```

### 3. 查看运行日志与健康状态

```bash
# 实时跟踪访问与错误日志 (JSON / 标准格式)
docker compose logs -f nginx

# 查看 Docker 原生 Healthcheck 探针状态 (healthy / unhealthy)
docker inspect --format='{{json .State.Health.Status}}' nginx
```

---

## 💡 扩展指南：如何新增任意容器的反代？

不需要修改 `docker-compose.yml` 中的环境变量，只要目标容器接入了 `frontend` 或 `backend` 网络，即可通过以下两种方式接入：

### 方式一：新增自定义站点模板 (推荐)

在 `gateways/nginx/templates/` 下新增 `minio.conf.template`：

```nginx
server {
    listen 443 ssl;
    http2 on;
    server_name minio.${SITE_ADDRESS};

    ssl_certificate /etc/nginx/ssl/live/${SITE_ADDRESS}/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/live/${SITE_ADDRESS}/privkey.pem;
    include /etc/nginx/snippets/ssl.conf;

    location / {
        include /etc/nginx/snippets/proxy.conf;
        # 核心：使用变量 + 容器名:端口，利用 Docker 内置 DNS 动态解析
        set $backend "minio:9000";
        proxy_pass http://$backend;
    }
}
```

执行 `docker compose up -d --build nginx` 重建即可生效。

---

## 🔒 证书与安全机制

1. **ACME 联动**：正式证书由 `gateways/lego` 服务自动向 Let's Encrypt 申请泛域名证书，保存在 `${DATA_PATH}ssl/live/${SITE_ADDRESS}/` 目录，供 Nginx 直接引用。
2. **启动自签兜底**：容器启动时，`05-init-ssl.sh` 会检查证书是否已就绪。若尚未生成，会自动调用 `openssl` 即时生成一张临时通配符证书（`*.${SITE_ADDRESS}`），杜绝因缺少 SSL 证书导致 Nginx 容器崩溃闪退。
3. **安全防护增强**：默认加载防刷限流（`anti-ddos.conf`）、基础 WAF 注入拦截（`waf.conf`）以及完整现代安全响应头（`security-headers.conf`，含 HSTS、No-Sniff、Frame-Options 等）。
