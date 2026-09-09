# Stirling-PDF 全功能本地 PDF 处理工具箱与微服务

[Stirling-PDF](https://github.com/Stirling-Tools/Stirling-PDF) 是当前 GitHub 上最流行（45k+ Stars）的开源自托管 PDF 处理服务。它提供美观易用的 Web 操作界面（支持移动端与暗黑模式）以及完整的 **REST API**（附带 OpenAPI / Swagger 规范），可作为企业内部的在线 PDF 瑞士军刀，也可作为后端业务系统的通用 PDF 处理微服务。

---

## 🎯 核心功能一览

Stirling-PDF 几乎涵盖了所有针对 PDF 文件的日常与工业级处理需求：

- 📑 **页面操作**：PDF 合并 (Merge)、拆分 (Split)、旋转、重新排序、多页合并为单页 (N-Up)、小册子排版。
- 🔄 **格式转换**：图片与 PDF 互转、HTML 转 PDF、Markdown 转 PDF、抽取纯文本。
- 🔍 **OCR 文字识别**：基于 Tesseract 引擎，为纯扫描件或图片型 PDF 添加可搜索、可复制的文本层。
- 🗜️ **压缩与优化**：通过 Ghostscript / QPDF 无损或有损压缩大幅缩减 PDF 文件体积。
- 🔒 **安全与合规**：添加/移除密码保护、修改权限许可、添加可见水印、数字签名、敏感信息涂黑遮盖 (Redaction)。
- 📊 **文档对比与修复**：两份 PDF 视觉差异比对、损坏文件修复、元数据 (Metadata) 提取与批量修改。

---

## 💡 为什么选用 `ultra-lite` 轻量镜像？

官方提供了 `latest`（全量镜像，约 1.8GB~2.2GB）和 **`ultra-lite`**（极轻量版，约 **~400MB**）：

| 维度 | **ultra-lite 轻量版 (本项目采用)** | **latest 全功能完整版** |
| :--- | :--- | :--- |
| **容器体积** | **~400MB** (内存开销低至 200MB 左右) | **~2GB+** (内置全套桌面版 LibreOffice 与全语种字库) |
| **涵盖核心能力** | 包含 90% 以上 PDF 核心操作 (合并、拆分、旋转、压缩、加密、水印、签名) | 包含上述全部功能 + 原生集成 LibreOffice Office 转 PDF |
| **OCR 支持** | 支持通过外挂数据卷挂载所需的 Tesseract 语言包 | 内置了部分默认语言模型，体积较大 |
| **架构适配** | 对轻量开发机、云服务器及 Mac ARM64 资源占用极低 | 资源开销大，冷启动慢 |

> [!TIP]
> 如果您的系统同时配置了专职的无头渲染引擎（如 `media/gotenberg`），那么由 Gotenberg 负责 HTML/网页转 PDF，由 Stirling-PDF `ultra-lite` 负责所有 PDF 文件级后处理（合并、盖章、压缩、加解密），是业界最均衡、最轻量的架构组合！

---

## 🏛️ 系统集成架构

```text
┌──────────────────────────────────────────────────────────────────────────────────┐
│                            1. 访问客户端 (Client Layer)                          │
├──────────────────────────────────────────────────────────────────────────────────┤
│  • 终端开发者 / 员工浏览器 (直接打开 Web 界面进行可视化拖拽操作)                 │
│  • PHP / Laravel 业务后端 (通过 Guzzle 发起 /api/v1/... REST API 调用)           │
│  • 微服务定时任务 Worker (批量压缩老旧归档 PDF、合并电子发票与凭证)             │
└────────────────────────────────────────┬─────────────────────────────────────────┘
                                         │
                                         │ 1. 访问 Web UI 或请求 REST API
                                         ▼
┌──────────────────────────────────────────────────────────────────────────────────┐
│                    2. 端口与网络接入层 (Port & Network Layer)                    │
├──────────────────────────────────────────────────────────────────────────────────┤
│  • 宿主机端口映射: 8089 -> stirling-pdf:8080                                     │
│  • 内部微服务通信网络: backend (直接通过 http://stirling-pdf:8080 互联)          │
│  • 可选 Caddy 反代: pdf.{$SITE_ADDRESS}                                          │
└────────────────────────────────────────┬─────────────────────────────────────────┘
                                         │
                                         │ 2. 转发请求
                                         ▼
┌──────────────────────────────────────────────────────────────────────────────────┐
│                        3. Stirling-PDF Spring Boot 引擎                          │
│                         (frooodle/s-pdf:2.14.3-ultra-lite)                       │
├──────────────────────────────────────────────────────────────────────────────────┤
│  • Web UI (中文语言默认启用: SYSTEM_DEFAULTLOCALE=zh-CN)                         │
│  • OpenAPI / Swagger 文档服务 (/swagger-ui/index.html)                           │
│  • Apache PDFBox / QPDF / Ghostscript 底层流式处理管线                           │
└───────────────────┬──────────────────────────────────────────────┬───────────────┘
                    │                                              │
                    │ 3a. 挂载持久化配置与自定义素材               │ 3b. 挂载 OCR 字库
                    ▼                                              ▼
┌────────────────────────────────────────┐     ┌───────────────────────────────────┐
│     4. 自定义配置与品牌资产持久化      │     │      5. Tesseract OCR 训练数据    │
│  • /configs:     服务运行配置          │     │  • /usr/share/tessdata            │
│  • /customFiles: 自定义品牌图标与样式  │     │    (可按需放入 chi_sim.traineddata)
│  • /logs:        运行日志文件          │     │                                   │
└────────────────────────────────────────┘     └───────────────────────────────────┘
```

---

## 🚀 快速上手与操作

### 1. 启动服务

本服务在 `media/docker-compose.yml` 中默认以注释方式按需提供。启动命令：

```bash
docker compose -f media/stirling-pdf/docker-compose.yml up -d
```

### 2. 浏览器打开 Web 操作台

在浏览器中输入：
👉 **`http://localhost:8089`**

- 默认界面已通过环境变量 `SYSTEM_DEFAULTLOCALE=zh-CN` 自动设置为**简体中文**。
- 默认免密登录模式（`SECURITY_ENABLE_LOGIN=false`），如需对外公开，可设为 `true` 开启多用户账户与权限体系。

### 3. 查看在线 REST API 文档 (Swagger)

在浏览器中输入：
👉 **`http://localhost:8089/swagger-ui/index.html`**

您可以查看几十个细分接口的参数规范，并可直接在网页上发起 Mock / Live 请求测试。

---

## 📡 API 调用示例

### 1. 合并多个 PDF 文件 (`/api/v1/general/merge-pdfs`)

```bash
curl -X POST "http://localhost:8089/api/v1/general/merge-pdfs" \
  -H "accept: application/pdf" \
  -H "Content-Type: multipart/form-data" \
  -F "fileInput=@document1.pdf" \
  -F "fileInput=@document2.pdf" \
  -o "merged.pdf"
```

### 2. 压缩并优化 PDF 体积 (`/api/v1/misc/compress-pdf`)

```bash
curl -X POST "http://localhost:8089/api/v1/misc/compress-pdf" \
  -H "accept: application/pdf" \
  -H "Content-Type: multipart/form-data" \
  -F "fileInput=@large_report.pdf" \
  -F "optimizeLevel=2" \
  -o "compressed.pdf"
```

- `optimizeLevel`: 压缩等级，`1` (轻度无损)、`2` (推荐中度)、`3` (深度强力压缩)。

### 3. 为 PDF 添加密码保护 (`/api/v1/security/add-password`)

```bash
curl -X POST "http://localhost:8089/api/v1/security/add-password" \
  -H "Content-Type: multipart/form-data" \
  -F "fileInput=@contract.pdf" \
  -F "password=MySecurePassword123" \
  -o "encrypted_contract.pdf"
```

---

## 🐘 PHP / Laravel 客户端接入示例

```php
<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;

class PdfManagerService
{
    protected string $baseUrl;

    public function __construct()
    {
        // 容器内互通直接使用容器名 stirling-pdf:8080
        $this->baseUrl = config('services.stirling_pdf.url', 'http://stirling-pdf:8080');
    }

    /**
     * 将多个本地 PDF 文件合并为一个
     *
     * @param array<string> $filePaths 本地 PDF 绝对路径数组
     */
    public function mergePdfs(array $filePaths): string
    {
        $request = Http::timeout(60);

        foreach ($filePaths as $path) {
            $request->attach('fileInput', file_get_contents($path), basename($path));
        }

        $response = $request->post("{$this->baseUrl}/api/v1/general/merge-pdfs");

        if ($response->successful()) {
            return $response->body(); // 二进制 PDF 内容
        }

        throw new \RuntimeException('PDF 合并失败: ' . $response->body());
    }
}
```

---

## ⚙️ 环境变量与配置说明

| 环境变量 | 默认值 | 说明 |
| :--- | :--- | :--- |
| `STIRLING_PDF_PORT` | `8089` | 宿主机映射的 Web UI 与 REST API 端口 |
| `STIRLING_PDF_ENABLE_LOGIN` | `false` | 是否开启登录鉴权模式（设为 `true` 可启用多用户账号体系） |
| `STIRLING_PDF_LOCALE` | `zh-CN` | Web 界面默认语言区域 (支持 `zh-CN`, `en-US` 等) |
| `DATA_PATH` | `./data/` | 持久化数据主目录，保存 OCR 语言模型、自定义配置与静态资源 |
| `LOG_PATH` | `./logs/` | 应用日志目录 |
