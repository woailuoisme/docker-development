# PHP / Laravel 全栈运行环境 (PHP Runtimes)

本模块统一整合了现代 Laravel 生态下最核心的 Web 引擎、常驻内存应用服务器、队列处理中心、定时调度器以及 WebSocket 实时长连接服务。

---

## 一、组件构成与职责划分

| 服务容器名 | 运行时核心 | 适用场景与特性 | 内部暴露端口 |
| :--- | :--- | :--- | :--- |
| **`php-fpm`** | PHP-FPM 8.x + FastCGI | 传统 Web 应用、稳定热更新、开发调试最佳体验 | `9000` |
| **`php-roadrunner`** | Laravel Octane + RoadRunner | 高性能常驻内存微服务、高并发 API 接口响应 | `8001` (宿主机: `8201`) |
| **`php-franken`** | Laravel Octane + FrankenPHP | 基于 Caddy 的现代化原生常驻服务器、极速冷启 | `8001` (宿主机: `8801`) |
| **`php-horizon`** | Laravel Horizon + Redis/Valkey | 异步队列任务处理中心与仪表盘监控 | - |
| **`php-schedule`** | Laravel Schedule (Cron Runner) | 毫秒级任务调度器，替代传统系统 crontab | - |
| **`php-reverb`** | Laravel Reverb | 官方原生高吞吐 WebSocket 服务器，长连接广播 | `8080` |

---

## 二、架构拓扑与数据流向

```text
                               ┌─────────────────────────────────┐
                               │           Caddy 网关            │
                               └───────┬─────────────────┬───────┘
                                       │                 │
                FastCGI (:9000)        │                 │ HTTP (:8001) / WS (:8080)
        ┌──────────────────────────────┘                 └──────────────────────────────┐
        ▼                                                                               ▼
┌──────────────┐                                                        ┌──────────────────────────────┐
│   php-fpm    │                                                        │ php-roadrunner / php-franken │
└───────┬──────┘                                                        └──────────────┬───────────────┘
        │                                                                              │
        │                                                                              │
        └───────────────────────────────┬──────────────────────────────────────────────┘
                                        │
                         派发异步任务 / 状态记录 / 广播
                                        │
                                        ▼
             ┌─────────────────────────────────────────────────────┐
             │                   Valkey / Redis                    │
             └───────────▲─────────────────────────────┬───────────┘
                         │ 消费任务                    │ 事件订阅
                         ▼                             ▼
                  ┌──────────────┐              ┌──────────────┐
                  │ php-horizon  │              │  php-reverb  │
                  └──────────────┘              └──────────────┘
                         ▲
                         │ 触发定时调度
                  ┌──────┴───────┐
                  │ php-schedule │
                  └──────────────┘
```

---

## 三、目录组织结构

```text
php/
├── docker-compose.yml               # 统一模块化总入口 (通过 include 聚合各子服务)
├── README.md                        # 架构与使用指南
├── fpm/                             # PHP-FPM FastCGI 环境
│   ├── docker-compose.yml           # FPM 服务独立编排
│   ├── Dockerfile
│   ├── config/                      # php.ini / opcache / xdebug / www.conf
│   ├── healthcheck.sh
│   └── startup.sh
├── roadrunner/                      # RoadRunner 常驻内存引擎
│   ├── docker-compose.yml           # RoadRunner 服务独立编排
│   ├── Dockerfile
│   ├── config/                      # .rr.yaml 与 php.ini
│   ├── healthcheck.sh
│   └── startup.sh
├── franken/                         # FrankenPHP 引擎
│   ├── docker-compose.yml           # FrankenPHP 服务独立编排
│   ├── Dockerfile
│   ├── config/                      # Caddyfile 与配置
│   ├── healthcheck.sh
│   └── startup.sh
├── horizon/                         # Horizon 队列处理
│   ├── docker-compose.yml           # Horizon 服务独立编排
│   ├── Dockerfile
│   ├── config/
│   ├── supervisord.conf
│   ├── healthcheck.sh
│   └── startup.sh
├── schedule/                        # Schedule 定时器
│   ├── docker-compose.yml           # Schedule 服务独立编排
│   ├── Dockerfile
│   ├── config/
│   └── startup.sh
└── reverb/                          # Reverb WebSocket
    ├── docker-compose.yml           # Reverb 服务独立编排
    ├── Dockerfile
    ├── config/
    ├── healthcheck.sh
    └── startup.sh
```

---

## 四、使用与运维操作

### 1. 启动指定运行模式

```bash
# 模式 A：经典 PHP-FPM + 异步队列 + 定时器
docker compose up -d php-fpm php-horizon php-schedule

# 模式 B：Octane (RoadRunner) 极速模式 + 队列 + WebSocket
docker compose up -d php-roadrunner php-horizon php-reverb

# 模式 C：Octane (FrankenPHP) 现代模式
docker compose up -d php-franken php-horizon
```

### 2. 容器内执行 Artisan / Composer 命令

```bash
# 进入 FPM 容器
docker compose exec php-fpm bash

# 执行数据迁移
docker compose exec php-fpm php artisan migrate

# 队列平滑重载
docker compose exec php-horizon php artisan horizon:terminate
```
