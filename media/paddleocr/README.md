# RapidOCR / PaddleOCR 现代高效文字识别微服务

本项目基于 [RapidOCR](https://github.com/RapidAI/RapidOCR) 及其官方服务化封装库 `rapidocr_api` 构建，将百度经典的 **PP-OCRv4** 工业级模型转换为 ONNX 格式，使用 **ONNXRuntime** 进行超高性能推理，并由 **FastAPI + Uvicorn** 提供现代化的异步 REST API 与在线 Swagger 交互文档。

---

## 🎯 为什么使用 RapidOCR 替代原版 PaddleOCR 容器？

传统的 PaddleOCR Docker 镜像（如社区历史的 `c403/paddleocr` 或百度官方底包）存在体积巨大、难以跨平台、API 简陋等问题。RapidOCR 针对服务化推理进行了全方位现代化重构：

| 维度 | **RapidOCR (本项目方案)** | **传统 PaddleOCR 镜像 (如 c403/paddleocr)** |
| :--- | :--- | :--- |
| **推理模型** | **PP-OCRv4** (最新检测与识别模型，中英文字符、倾斜文字、复杂背景识别精度飞跃) | PP-OCRv2 / 早期模型 (识别率与泛化能力较弱) |
| **底层引擎** | **ONNXRuntime (轻量化 C++ 运行时)**，CPU 吞吐量极高，内存占用仅 100~200MB | PaddlePaddle 完整框架 (未剪枝动态图)，内存开销动辄 1.5GB+ |
| **容器体积** | **~300MB** (基于 `python:3.11-slim` 与 `opencv-python-headless`) | **2.5GB ~ 4GB+** (包含大量无用的训练模块与 GUI 依赖) |
| **架构兼容** | **原生支持 x86_64 与 macOS Apple Silicon (ARM64)**，M系列芯片上推理极快 | 仅支持 x86_64，在 Mac 上依赖 Rosetta 转译，极易出现崩溃与卡顿 |
| **API 规范** | **FastAPI + Uvicorn** 异步高并发架构，自带 `/docs` (Swagger UI) 在线测试与 OpenAPI 规范 | 早期简陋 Flask 阻塞服务，无在线调试界面，无健康检查机制 |
| **维护状态** | RapidAI 工业团队持续维护迭代 | 个人打包维护，普遍已停更 3 年以上 |

---

## 🏛️ 系统集成架构

```text
┌──────────────────────────────────────────────────────────────────────────────────┐
│                            1. 客户端 / 调用方 (Client Layer)                     │
├──────────────────────────────────────────────────────────────────────────────────┤
│  • PHP / Laravel 应用 (通过 Guzzle / HTTP Client 异步发起 OCR 识别)              │
│  • 浏览器 / 开发者 (直接访问 http://localhost:8092/docs 进行可视化测试)          │
│  • 微服务业务层 (票据扫描、证件比对、PDF 文档文字提取)                          │
└────────────────────────────────────────┬─────────────────────────────────────────┘
                                         │
                                         │ 1. POST /ocr (上传二进制图片或 Base64)
                                         ▼
┌──────────────────────────────────────────────────────────────────────────────────┐
│                    2. 网关与网络接入层 (Caddy Ingress / Docker Network)          │
├──────────────────────────────────────────────────────────────────────────────────┤
│  • 宿主机端口映射: 8092 -> paddleocr:5000                                        │
│  • 内部微服务通信网络: backend (直接通过 http://paddleocr:5000 互联)            │
└────────────────────────────────────────┬─────────────────────────────────────────┘
                                         │
                                         │ 2. 路由分发
                                         ▼
┌──────────────────────────────────────────────────────────────────────────────────┐
│                        3. RapidOCR FastAPI 微服务容器                            │
│                        (media/paddleocr/Dockerfile)                              │
├──────────────────────────────────────────────────────────────────────────────────┤
│  • Uvicorn + FastAPI 异步请求处理与参数校验                                      │
│  • 图像预处理 (OpenCV Headless 图像解码与矩阵归一化)                             │
│  • PP-OCRv4 文本检测 (Text Detection)                                            │
│  • 文本方向分类 (Direction Classifier, 自动校正 90°/180°/270° 旋转)              │
│  • PP-OCRv4 文本识别 (Text Recognition, 输出文本内容与置信度分数)                │
└────────────────────────────────────────┬─────────────────────────────────────────┘
                                         │
                                         │ 3. 模型持久化缓存
                                         ▼
┌──────────────────────────────────────────────────────────────────────────────────┐
│                        4. 本地持久化缓存卷 (Data Volume)                         │
│             ${DATA_PATH}paddleocr -> /root/.cache (避免重复下载模型权重)         │
└──────────────────────────────────────────────────────────────────────────────────┘
```

---

## 🚀 快速上手与验证

### 1. 启动服务

本服务已在 `media/docker-compose.yml` 中按需注册。如需启用与构建：

```bash
# 1. 验证 Dockerfile 规范
just lint-docker

# 2. 构建并启动 RapidOCR 容器
docker compose -f media/paddleocr/docker-compose.yml up -d --build
```

### 2. 在线可视化测试 (Swagger UI)

容器启动后，在浏览器直接打开：
👉 **`http://localhost:8092/docs`**

您可以看到标准的 OpenAPI / Swagger 页面，展开 `POST /ocr` 接口即可直接在网页上选择本地图片上传测试，即时查看 JSON 识别返回。

---

## 📡 API 调用示例

### 1. 使用 cURL 调用 (文件上传)

```bash
curl -X POST "http://localhost:8092/ocr" \
  -H "accept: application/json" \
  -H "Content-Type: multipart/form-data" \
  -F "file=@/path/to/your/image.png"
```

### 2. 使用 cURL 调用 (Base64 JSON)

```bash
# 将图片编码为 Base64 字符串后发送
curl -X POST "http://localhost:8092/ocr" \
  -H "Content-Type: application/json" \
  -d '{"image_dir": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUg..."}'
```

### 3. API 典型 JSON 响应格式

```json
{
  "code": 200,
  "msg": "success",
  "data": [
    {
      "box": [
        [38.0, 42.0],
        [240.0, 42.0],
        [240.0, 85.0],
        [38.0, 85.0]
      ],
      "text": "中华人民共和国发票",
      "score": 0.9854
    },
    {
      "box": [
        [38.0, 95.0],
        [180.0, 95.0],
        [180.0, 130.0],
        [38.0, 130.0]
      ],
      "text": "金额：￥1,280.00",
      "score": 0.9921
    }
  ]
}
```

- `box`: 文字在图片中的 4 个顶点坐标 `[[x1, y1], [x2, y2], [x3, y3], [x4, y4]]`。
- `text`: OCR 识别出的文本内容。
- `score`: 置信度（0.0 ~ 1.0），越接近 1.0 准确率越高。

---

## 🐘 PHP / Laravel 客户端接入示例

在 Laravel 控制器或服务类中，可以直接利用 HTTP Client 进行微服务内部调用：

```php
<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Http\UploadedFile;

class OcrService
{
    protected string $baseUrl;

    public function __construct()
    {
        // 容器网络互联直接使用容器名 paddleocr:5000
        $this->baseUrl = config('services.ocr.url', 'http://paddleocr:5000');
    }

    /**
     * 识别上传的图片文本
     */
    public function recognize(UploadedFile $file): array
    {
        $response = Http::timeout(30)
            ->attach('file', file_get_contents($file->getRealPath()), $file->getClientOriginalName())
            ->post("{$this->baseUrl}/ocr");

        if ($response->successful()) {
            return $response->json('data', []);
        }

        throw new \RuntimeException('OCR 服务请求失败: ' . $response->body());
    }
}
```

---

## ⚙️ 环境变量与配置说明

| 变量名 | 默认值 | 说明 |
| :--- | :--- | :--- |
| `PADDLEOCR_PORT` | `8092` | 宿主机映射的 API 服务端口 (支持 Swagger UI `/docs`) |
| `DATA_PATH` | `./data/` | 宿主机持久化目录主路径，模型缓存保存在 `${DATA_PATH}paddleocr` |
