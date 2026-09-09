# Gotenberg 无头浏览器文档与网页转 PDF 微服务

[Gotenberg](https://github.com/gotenberg/gotenberg) 是一款基于 Go 语言构建的现代化无状态 (Stateless) REST API 微服务，专门用于通过无头 Chromium 浏览器将 HTML 文件、网页 URL 以及 Markdown 高度保真地渲染并转换为 PDF 文档和图片。

---

## 🎯 为什么选择 Gotenberg？

在企业级应用（报表打印、电子凭证、电商发票、账单清单）开发中，服务端生成高质量 PDF 一直是一个技术痛点。传统方案（如 wkhtmltopdf、Dompdf、mPDF 等）对现代 CSS（Flexbox、CSS Grid、CSS 变量）、Web 字体以及 JavaScript 动态图表（如 ECharts）支持非常有限。

Gotenberg 完美解决了上述痛点：

| 维度 | **Gotenberg (-chromium 方案)** | **传统方案 (wkhtmltopdf / Dompdf / mPDF)** |
| :--- | :--- | :--- |
| **渲染内核** | **真实 Google Chromium 内核**，支持现代 CSS3、Flexbox、Grid 及 Web 字体 | 早期 WebKit 或纯 PHP 模拟器，不支持 Flexbox / Grid，复杂排版错位严重 |
| **动态图表** | **支持执行 JavaScript**，可等待 ECharts / Chart.js 绘制完毕后再打印 | 完全无法执行复杂 JS 图表与动态数据绑定 |
| **架构与稳定性** | **无状态 (Stateless) 架构**，每次转换均在独立隔离的 Chromium 标签页中执行 | 进程常驻容易内存泄漏 (Memory Leak)，长时间运行容易僵死 |
| **镜像优化** | 采用官方 **`-chromium` 轻量变体** (~1.2GB)，剔除臃肿的 LibreOffice，秒级冷启动 | 许多方案依赖完整桌面环境或繁琐的宿主机依赖库 |
| **API 规范** | 标准 HTTP Multipart 接口，支持页眉 (Header)、页脚 (Footer)、页码自动计算 | 需通过命令行执行 `exec()`，并发处理难度高且存在安全注入隐患 |

---

## 🏛️ 系统集成架构

```text
┌──────────────────────────────────────────────────────────────────────────────────┐
│                            1. 业务调用端 (Client Layer)                          │
├──────────────────────────────────────────────────────────────────────────────────┤
│  • PHP / Laravel 业务后端 (通过 Guzzle / gotenberg-php 客户端发送请求)           │
│  • 定时报表生成任务 (夜间批量渲染各部门运营 PDF 简报)                            │
│  • 移动端 / Web 前端 (发起 URL 抓取或长页面生成 PDF 导出)                        │
└────────────────────────────────────────┬─────────────────────────────────────────┘
                                         │
                                         │ 1. POST /forms/chromium/convert/...
                                         ▼
┌──────────────────────────────────────────────────────────────────────────────────┐
│                    2. 端口与网络接入层 (Port & Network Layer)                    │
├──────────────────────────────────────────────────────────────────────────────────┤
│  • 宿主机端口映射: 3080 -> gotenberg:3000                                        │
│  • 内部微服务通信网络: backend (直接通过 http://gotenberg:3000 互通)             │
└────────────────────────────────────────┬─────────────────────────────────────────┘
                                         │
                                         │ 2. 路由分发
                                         ▼
┌──────────────────────────────────────────────────────────────────────────────────┐
│                        3. Gotenberg 高性能 Go 微服务引擎                         │
│                      (gotenberg/gotenberg:8.36-chromium)                         │
├──────────────────────────────────────────────────────────────────────────────────┤
│  • Go HTTP Server 协程池与超时控制 (默认 30s/60s 超时管理)                       │
│  • Chromium 实例池与标签页自动生命周期回收                                       │
│  • 智能等待策略 (等待网络空闲 / 等待特定 JS 条件表达式满足)                      │
│  • PDFtk / Qpdf 底层引擎 (页面合并、元数据写入)                                  │
└────────────────────────────────────────┬─────────────────────────────────────────┘
                                         │
                                         │ 3. 实时返回二进制 PDF 流
                                         ▼
┌──────────────────────────────────────────────────────────────────────────────────┐
│                            4. 生成结果 (Result Output)                           │
│                 application/pdf 或 image/png (直接下载或入库持久化)              │
└──────────────────────────────────────────────────────────────────────────────────┘
```

---

## 🚀 快速上手与验证

### 1. 启动服务

本服务在 `media/docker-compose.yml` 中支持按需引入，也可直接单独启动：

```bash
docker compose -f media/gotenberg/docker-compose.yml up -d
```

### 2. 健康检查探测

```bash
curl -f http://localhost:3080/health
# 返回: {"status":"up"}
```

---

## 📡 核心 API 调用示例

### 1. 将远程或本地网页 URL 转为 PDF (`/forms/chromium/convert/url`)

```bash
curl \
  --request POST 'http://localhost:3080/forms/chromium/convert/url' \
  --form 'url="https://example.com"' \
  --form 'paperWidth="8.27"' \
  --form 'paperHeight="11.69"' \
  --form 'marginTop="0.4"' \
  --form 'marginBottom="0.4"' \
  -o "example.pdf"
```

### 2. 将本地 HTML 文件及素材转为 PDF (`/forms/chromium/convert/html`)

Gotenberg 允许同时上传 `index.html`，以及可选的 `header.html`（页眉）、`footer.html`（页脚）和相关图片/CSS 样式表：

```bash
curl \
  --request POST 'http://localhost:3080/forms/chromium/convert/html' \
  --form 'files=@"index.html"' \
  --form 'files=@"style.css"' \
  --form 'files=@"header.html"' \
  --form 'files=@"footer.html"' \
  --form 'paperWidth="8.27"' \
  --form 'paperHeight="11.69"' \
  -o "invoice.pdf"
```

> [!TIP]
> **自动分页与页码注入**：在 `header.html` 或 `footer.html` 中，只要给 HTML 元素指定对应的 class，Chromium 就会自动替换：
>
> - `<span class="pageNumber"></span>`：当前页码
> - `<span class="totalPages"></span>`：总页数

### 3. 合并多个 PDF 文件 (`/forms/pdfengines/merge`)

```bash
curl \
  --request POST 'http://localhost:3080/forms/pdfengines/merge' \
  --form 'files=@"cover.pdf"' \
  --form 'files=@"body.pdf"' \
  --form 'files=@"appendix.pdf"' \
  -o "complete_book.pdf"
```

---

## 🐘 PHP / Laravel 客户端接入示例

在 Laravel 中，您既可以使用官方的 `gotenberg/gotenberg-php` 扩展包，也可以直接使用框架自带的 `Http` 门面：

```php
<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;

class InvoicePdfService
{
    protected string $baseUrl;

    public function __construct()
    {
        // 容器内微服务直接使用容器名 gotenberg:3000
        $this->baseUrl = config('services.gotenberg.url', 'http://gotenberg:3000');
    }

    /**
     * 将 Blade 渲染出的 HTML 生成为 PDF 二进制流
     */
    public function generateInvoice(array $orderData): string
    {
        // 1. 渲染 Laravel Blade 模板
        $htmlContent = view('invoices.template', ['order' => $orderData])->render();

        // 2. 发起 Gotenberg API 转换请求
        $response = Http::timeout(30)
            ->attach('files', $htmlContent, 'index.html')
            ->post("{$this->baseUrl}/forms/chromium/convert/html", [
                'paperWidth'   => '8.27', // A4 宽度 (英寸)
                'paperHeight'  => '11.69', // A4 高度 (英寸)
                'marginTop'    => '0.4',
                'marginBottom' => '0.4',
                'marginLeft'   => '0.4',
                'marginRight'  => '0.4',
                'preferCssPageSize' => 'true',
            ]);

        if ($response->successful()) {
            return $response->body(); // 返回 PDF 二进制内容
        }

        throw new \RuntimeException('Gotenberg PDF 转换失败: ' . $response->body());
    }
}
```

---

## ⚙️ 环境变量与配置说明

| 环境变量 | 默认值 | 说明 |
| :--- | :--- | :--- |
| `GOTENBERG_PORT` | `3080` | 宿主机映射的 API 服务端口 |
| `GOTENBERG_VERSION` | `8.36-chromium` | 容器镜像版本，采用专精 HTML 渲染的轻量 Chromium 变体 |
