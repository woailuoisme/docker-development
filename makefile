SHELL = /bin/bash
DC_RUN_ARGS = -f docker-compose.yml
DC_SUPERVISOR_PATH = /usr/local/etc/supervisord.conf
DC_SUPERVISOR_PATH = 'export PYTHONWARNINGS="ignore::UserWarning:supervisor.options"'
HOST_UID = $(shell id -u)
HOST_GID = $(shell id -g)

# Default configuration variables
REGISTRY ?= jiaoio
IMAGE_NAME ?= php-base
PHP_VERSION ?= 8.4
TAG ?= latest
WWWGROUP ?= $(shell id -g)

include $(PWD)/.env
export

.PHONY: help

# =============================================================================
# HELP TARGET
# =============================================================================
.DEFAULT_GOAL: help

help: ## Show this help message
	@echo "Lunchbox Docker Environment Management"
	@echo "======================================"
	@echo ""
	@echo "Available commands:"
	@echo ""
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-25s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""

# =============================================================================
# DOCKER COMPOSE MANAGEMENT
# =============================================================================

up: ## Start all containers in background
	docker compose ${DC_RUN_ARGS} up -d --remove-orphans

down: ## Stop all containers
	docker compose ${DC_RUN_ARGS} down

down-with-volumes: ## Stop containers and remove volumes
	docker compose ${DC_RUN_ARGS} down -v

restart: ## Restart all containers
	docker compose ${DC_RUN_ARGS} restart

logs: ## Tail all containers logs
	docker compose ${DC_RUN_ARGS} logs -f

logs-%: ## Tail logs for specific service
	docker compose ${DC_RUN_ARGS} logs -f $*

ps: ## Show container status with formatted output
	@echo "📊 Container Status:"
	@echo "=================="
	@docker compose ${DC_RUN_ARGS} ps --format "table {{.Name}}\t{{.Service}}\t{{.Status}}\t{{.Ports}}" | \
	awk ' \
		NR==1 {print "📋 " $$0; next} \
		/unhealthy/ {print "❌ " $$0; next} \
		/healthy/ {print "✅ " $$0; next} \
		{print "⚠️  " $$0} \
	'

remove-orphans: ## Remove orphaned containers
	docker compose ${DC_RUN_ARGS} down --remove-orphans

stop-all: ## Stop all running containers (forceful)
	docker stop $$(docker ps -a -q)

kill-all: ## Force kill all containers (emergency only)
	docker kill $$(docker ps -q)

# =============================================================================
# CONTAINER SHELL ACCESS
# =============================================================================

shell-php-fpm: ## Start shell into php-fpm container
	docker compose ${DC_RUN_ARGS} exec php-fpm sh

shell-nginx: ## Start shell into nginx container
	docker compose ${DC_RUN_ARGS} exec nginx sh

shell-postgres: ## Start shell into postgres container
	docker compose ${DC_RUN_ARGS} exec postgres sh

shell-redis: ## Start shell into redis container
	docker compose ${DC_RUN_ARGS} exec redis sh

command-php-fpm: ## Run a command in the php-fpm container
	docker compose ${DC_RUN_ARGS} exec php-fpm sh -c "$(command)"

# =============================================================================
# SUPERVISOR MANAGEMENT
# =============================================================================

#supervisor-start: ## Start supervisord in running container
#	@echo "🚀 Starting supervisord..."
#	docker compose ${DC_RUN_ARGS} exec php-fpm supervisord -c /usr/local/etc/supervisord.conf

supervisor-start: ## Start supervisord in background
	@echo "🚀 Starting supervisord in background..."
	docker compose ${DC_RUN_ARGS} exec -d php-fpm supervisord -c /usr/local/etc/supervisord.conf

supervisor-status: ## Check supervisord status
	@echo "📊 Checking supervisord status..."
	docker compose ${DC_RUN_ARGS} exec -T php-fpm sh -c 'export PYTHONWARNINGS="ignore::UserWarning:supervisor.options" && supervisorctl -c /usr/local/etc/supervisord.conf -s http://127.0.0.1:9201 status'

supervisor-reload: ## Reload configuration and restart all processes
	@echo "🔄 Reloading supervisord configuration and restarting all processes..."
	docker compose ${DC_RUN_ARGS} exec -T php-fpm sh -c 'export PYTHONWARNINGS="ignore::UserWarning:supervisor.options" && supervisorctl -c /usr/local/etc/supervisord.conf -s http://127.0.0.1:9201 reload'

supervisor-down: ## Shutdown supervisord and all managed processes
	@echo "🛑 Shutting down supervisord and all managed processes..."
	docker compose ${DC_RUN_ARGS} exec -T php-fpm sh -c 'export PYTHONWARNINGS="ignore::UserWarning:supervisor.options" && supervisorctl -c /usr/local/etc/supervisord.conf -s http://127.0.0.1:9201 shutdown'

supervisor-start-process: ## Start specific supervisor process
	@echo "🚀 Starting supervisor process: $(process)..."
	docker compose ${DC_RUN_ARGS} exec -T php-fpm sh -c 'export PYTHONWARNINGS="ignore::UserWarning:supervisor.options" && supervisorctl -c /usr/local/etc/supervisord.conf -s http://127.0.0.1:9201 start $(process)'

supervisor-stop-process: ## Stop specific supervisor process
	@echo "🛑 Stopping supervisor process: $(process)..."
	docker compose ${DC_RUN_ARGS} exec -T php-fpm sh -c 'export PYTHONWARNINGS="ignore::UserWarning:supervisor.options" && supervisorctl -c /usr/local/etc/supervisord.conf -s http://127.0.0.1:9201 stop $(process)'

supervisor-restart-process: ## Restart specific supervisor process
	@echo "🔄 Restarting supervisor process: $(process)..."
	docker compose ${DC_RUN_ARGS} exec -T php-fpm sh -c 'export PYTHONWARNINGS="ignore::UserWarning:supervisor.options" && supervisorctl -c /usr/local/etc/supervisord.conf -s http://127.0.0.1:9201 restart $(process)'

supervisor-tail-logs: ## Tail logs for specific process
	@echo "📋 Tailing logs for process: $(process)..."
	docker compose ${DC_RUN_ARGS} exec -T php-fpm sh -c 'export PYTHONWARNINGS="ignore::UserWarning:supervisor.options" && supervisorctl -c /usr/local/etc/supervisord.conf -s http://127.0.0.1:9201 tail -f $(process)'

supervisor-clear-logs: ## Clear logs for specific process
	@echo "🧹 Clearing logs for process: $(process)..."
	docker compose ${DC_RUN_ARGS} exec -T php-fpm sh -c 'export PYTHONWARNINGS="ignore::UserWarning:supervisor.options" && supervisorctl -c /usr/local/etc/supervisord.conf -s http://127.0.0.1:9201 clear $(process)'

supervisor-reread: ## Reread configuration without restarting
	@echo "📖 Rereading supervisor configuration..."
	docker compose ${DC_RUN_ARGS} exec -T php-fpm sh -c 'export PYTHONWARNINGS="ignore::UserWarning:supervisor.options" && supervisorctl -c /usr/local/etc/supervisord.conf -s http://127.0.0.1:9201 reread'

supervisor-update: ## Update configuration (restart changed processes only)
	@echo "🔄 Updating supervisor configuration..."
	docker compose ${DC_RUN_ARGS} exec -T php-fpm sh -c 'export PYTHONWARNINGS="ignore::UserWarning:supervisor.options" && supervisorctl -c /usr/local/etc/supervisord.conf -s http://127.0.0.1:9201 update'

supervisor-version: ## Show supervisor version
	@echo "📋 Checking supervisor version..."
	docker compose ${DC_RUN_ARGS} exec -T php-fpm sh -c 'export PYTHONWARNINGS="ignore::UserWarning:supervisor.options" && supervisorctl -c /usr/local/etc/supervisord.conf -s http://127.0.0.1:9201 version'

# =============================================================================
# NGINX MANAGEMENT
# =============================================================================

nginx-check: ## Check Nginx configuration syntax
	@echo "🔍 Checking Nginx configuration syntax..."
	docker compose ${DC_RUN_ARGS} exec nginx nginx -t

nginx-reload: ## Reload Nginx configuration (without restarting container)
	@echo "🔄 Reloading Nginx configuration..."
	docker compose ${DC_RUN_ARGS} exec nginx nginx -s reload

nginx-restart: ## Restart Nginx service
	@echo "🔄 Restarting Nginx service..."
	docker compose ${DC_RUN_ARGS} restart nginx

nginx-check-restart: ## Check Nginx configuration and restart if valid
	@echo "🔍 Checking Nginx configuration and restarting..."
	@if docker compose ${DC_RUN_ARGS} exec nginx nginx -t; then \
		echo "✅ Nginx configuration check passed, restarting service..."; \
		docker compose ${DC_RUN_ARGS} restart nginx; \
		echo "✅ Nginx service restarted"; \
	else \
		echo "❌ Nginx configuration check failed, please check configuration files"; \
		exit 1; \
	fi

# =============================================================================
# SERVICE HEALTH CHECKS
# =============================================================================

check-php-fpm: ## Check PHP-FPM service health
	@echo "🔍 Checking PHP-FPM service..."
	docker compose ${DC_RUN_ARGS} exec php-fpm php-fpm -t

check-nginx: ## Check Nginx service health
	@echo "🔍 Checking Nginx service..."
	docker compose ${DC_RUN_ARGS} exec nginx nginx -t

check-postgres: ## Check PostgreSQL service health
	@echo "🔍 Checking PostgreSQL service..."
	docker compose ${DC_RUN_ARGS} exec postgres pg_isready

check-redis: ## Check Redis service health
	@echo "🔍 Checking Redis service..."
	docker compose ${DC_RUN_ARGS} exec redis redis-cli ping

check-all: ## Check all services health
	@echo "🔍 Running comprehensive service health checks..."
	@$(MAKE) check-php-fpm
	@$(MAKE) check-nginx
	@$(MAKE) check-postgres
	@$(MAKE) check-redis
	@echo "✅ All service health checks completed"

check-containers: ## Check container status
	@echo "🔍 Checking container status..."
	docker compose ${DC_RUN_ARGS} ps

# =============================================================================
# BUILD AND DEPLOYMENT
# =============================================================================

build: ## Build all services
	docker compose ${DC_RUN_ARGS} build``

build-%: ## Build specific service
	docker compose ${DC_RUN_ARGS} build $*

rebuild: ## Rebuild all services (force)
	docker compose ${DC_RUN_ARGS} build --no-cache

rebuild-%: ## Rebuild specific service (force)
	docker compose ${DC_RUN_ARGS} build --no-cache $*

pull: ## Pull latest images
	docker compose ${DC_RUN_ARGS} pull

# =============================================================================
# DEVELOPMENT UTILITIES
# =============================================================================

compose-validate: ## Validate docker-compose configuration
	docker compose ${DC_RUN_ARGS} config

show-versions: ## Show service versions
	@echo "📋 Service Versions:"
	@echo "==================="
	@echo "PHP-FPM: $$(docker compose ${DC_RUN_ARGS} exec php-fpm php -v | head -1)"
	@echo "Nginx: $$(docker compose ${DC_RUN_ARGS} exec nginx nginx -v 2>&1)"
	@echo "PostgresSQL: $$(docker compose ${DC_RUN_ARGS} exec postgres psql --version)"
	@echo "Redis: $$(docker compose ${DC_RUN_ARGS} exec redis redis-server --version | head -1)"

clean-images: ## Remove unused Docker images
	docker image prune -f

clean-volumes: ## Remove unused Docker volumes
	docker volume prune -f

clean-all: ## Remove all unused Docker resources
	docker system prune -f

# =============================================================================
# SECURITY AND CERTIFICATES
# =============================================================================

cert: ## Check SSL certificates
	@echo "🔐 Checking SSL certificates..."
	@docker compose ${DC_RUN_ARGS} exec nginx openssl x509 -in /etc/nginx/ssl/live/haoxiaoguai.xyz/fullchain.pem -text -noout | grep -E "(Subject:|Not Before:|Not After :)"

check-caddy: ## Check Caddy service
	@echo "🔍 Checking Caddy service..."
	@docker compose ${DC_RUN_ARGS} exec caddy caddy validate --config /etc/caddy/Caddyfile

#https://caddyserver.com/docs/running#docker-compose
trust-caddy-cert: ## Trust Caddy root certificate on macOS https://caddyserver.com/docs/running#docker-compose
	@echo "🔐 Installing Caddy root certificate to macOS system keychain..."
	@docker compose ${DC_RUN_ARGS} cp \
		caddy:/data/caddy/pki/authorities/local/root.crt \
		/tmp/root.crt \
	&& sudo security add-trusted-cert -d -r trustRoot \
		-k /Library/Keychains/System.keychain /tmp/root.crt
	@echo "✅ Caddy root certificate installed successfully"

trust-caddy-cert-linux: ## Trust Caddy root certificate on Linux
	@echo "🔐 Installing Caddy root certificate on Linux..."
	@docker compose ${DC_RUN_ARGS} cp \
		caddy:/data/caddy/pki/authorities/local/root.crt \
		/usr/local/share/ca-certificates/root.crt \
	&& sudo update-ca-certificates
	@echo "✅ Caddy root certificate installed successfully on Linux"

trust-caddy-cert-windows: ## Trust Caddy root certificate on Windows
	@echo "🔐 Installing Caddy root certificate on Windows..."
	@docker compose ${DC_RUN_ARGS} cp \
		caddy:/data/caddy/pki/authorities/local/root.crt \
		%TEMP%/root.crt \
	&& certutil -addstore -f "ROOT" %TEMP%/root.crt
	@echo "✅ Caddy root certificate installed successfully on Windows"

authelia-config-validate: ## Validate Authelia configuration
	@echo "🔍 Validating Authelia configuration..."
	@docker compose ${DC_RUN_ARGS} exec authelia authelia validate-config

authelia-generate-password: ## Generate Authelia password hash
	@echo "🔑 Generating Authelia password hash..."
	@docker compose ${DC_RUN_ARGS} exec authelia authelia crypto hash generate argon2 --password '$(password)'

# =============================================================================
# SSH MANAGEMENT
# =============================================================================

ssh-gen: ## Generate SSH key pair
	@echo "🔑 Generating SSH key pair..."
	ssh-keygen -t rsa -b 4096 -C "lunchbox@haoxiaoguai.xyz" -f ./ssh/id_rsa -N ""

ssh-copy-id: ## Copy SSH public key to server
	@echo "📤 Copying SSH public key to server..."
	ssh-copy-id -i ./ssh/id_rsa.pub $(user)@$(host)

ssh: ## SSH into server
	@echo "🔗 Connecting to server via SSH..."
	ssh -i ./ssh/id_rsa $(user)@$(host)

ssh-a: ## SSH with agent forwarding
	@echo "🔗 Connecting to server with agent forwarding..."
	ssh -A -i ./ssh/id_rsa $(user)@$(host)

# =============================================================================
# QUICK ACTIONS
# =============================================================================

dev: ## Start development environment
	@$(MAKE) up
	@$(MAKE) check-all

reset: ## Reset development environment
	@$(MAKE) down
	@$(MAKE) up

update: ## Update all services
	@$(MAKE) pull
	@$(MAKE) down
	@$(MAKE) up

status: ## Show comprehensive status
	@$(MAKE) ps
	@$(MAKE) check-all

# =============================================================================
# MAINTENANCE
# =============================================================================

backup-db: ## Backup PostgresSQL database
	@echo "💾 Backing up PostgreSQL database..."
	@docker compose ${DC_RUN_ARGS} exec postgres pg_dump -U $(POSTGRES_USER) $(POSTGRES_DB) > backup/$(shell date +%Y%m%d_%H%M%S)_backup.sql
	@echo "✅ Backup completed: backup/$(shell date +%Y%m%d_%H%M%S)_backup.sql"

restore-db: ## Restore PostgresSQL database from backup
	@echo "🔄 Restoring PostgresSQL database from $(file)..."
	@docker compose ${DC_RUN_ARGS} exec -T postgres psql -U $(POSTGRES_USER) $(POSTGRES_DB) < $(file)
	@echo "✅ Database restored from $(file)"

view-logs: ## View all service logs (one-time)
	docker compose ${DC_RUN_ARGS} logs

clean-logs: ## Clean container logs
	@echo "🧹 Cleaning container logs..."
	@find ./logs -name "*.log" -type f -delete
	@echo "✅ Logs cleaned"

portainer-reset-password:
	docker run --rm -v ./data/portainer_data:/data portainer/helper-reset-password

dozzle-pwd:
	docker run --rm amir20/dozzle generate Admin --name Admin --email me@email.net --password admin_secret

build-base-franken:
	cd php-base-franken && docker buildx build \
	--platform linux/amd64,linux/arm64 \
	--build-arg CHANGE_SOURCE=true \
	--tag docker.io/php-base-franken:php8.4-alpine \
	--tag docker.io/php-base-franken:php8.4-alpine-latest \
	--tag docker.io/php-base-franken:php8.4-latest \
	--push \
	.
build-base:
	cd php-base-cli && docker buildx build  \
	--platform linux/amd64,linux/arm64 \
	--build-arg CHANGE_SOURCE=true \
	--tag docker.io/php-base:php8.4-alpine3.22 \
	--tag docker.io/php-base:php8.4-alpine3.22-latest \
	--push \
	.

php-fpm-gd:
	docker exec php-fpm php -r "var_dump(gd_info());"

php-franken-gd:
	docker exec php-franken php -r "var_dump(gd_info());"

list-tags:
	skopeo list-tags docker://ghcr.io/gethomepage/homepage

pg-data-17-to18:
	docker run --rm \
      -v ./data/postgres:/var/lib/postgresql/17/data \
      -v ./data/postgres18:/var/lib/postgresql/18/data \
      -e POSTGRES_INITDB_ARGS="--no-data-checksums" \
      tianon/postgres-upgrade:17-to-18 --check


redis_test:
	redis-benchmark -h 127.0.0.1 -p 46379 -a redis_secret -n 100000 -q

postgres_test:

