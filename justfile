set dotenv-load := true

# 路径定义
caddy_root_cert := "./data/caddy/pki/authorities/local/root.crt"

# 快捷别名
alias fmt := fmt-md
alias validate-docker-compose := lint-compose

# 运行全量代码与配置检测
lint: lint-sh lint-docker lint-caddy lint-compose lint-actions lint-md

# 格式化 Markdown
fmt-md:
    rumdl fmt

# 检查 Markdown 文档
lint-md:
    rumdl check .

# 检查 Shell 脚本
lint-sh:
    fd --type file --extension sh --exclude data --exec-batch shellcheck --severity=warning

# 检查 Dockerfile
lint-docker:
    fd --type file '^Dockerfile.*$' --exclude data --exec-batch hadolint

# 检查 GitHub Actions 工作流
lint-actions:
    actionlint

# 验证 Docker Compose 配置
lint-compose:
    docker-compose config >/dev/null

# 验证 Caddy 配置文件
lint-caddy:
    docker-compose run --rm --no-deps caddy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile

# 测试 Caddy 代理
test-proxy:
    ./test_caddy_proxy.sh

# 安装 Caddy 根证书到 macOS 系统钥匙串
trust-cert:
    #!/usr/bin/env bash
    if [ -f "{{ caddy_root_cert }}" ]; then
        echo "正在安装 Caddy 根证书到 macOS 系统钥匙串..."
        sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "{{ caddy_root_cert }}"
        echo "证书安装成功！"
    else
        echo "错误: 找不到证书文件 {{ caddy_root_cert }}"
        echo "请确保 Caddy 服务已经启动并生成了证书。"
    fi
