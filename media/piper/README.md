# Piper 本地极速神经语音合成 (TTS) 微服务

[Piper](https://github.com/rhasspy/piper) 是由 Rhasspy 社区开源的一款快速、轻量且音质出色的本地神经文本转语音 (Text-to-Speech) 引擎。本项目采用官方 [Wyoming Piper](https://github.com/rhasspy/wyoming-piper) 容器镜像，专为低资源消耗、低延迟流式语音合成设计，在普通 CPU 上可达到实时语速的 10~20 倍生成性能。

---

## 🎯 为什么选择 Piper？

在传统的语音合成方案中，依赖云端商业 API（如 Azure TTS、OpenAI Audio、阿里云语音）存在网络延迟、外网带宽消耗、按量付费以及敏感文本隐私泄露等痛点。Piper 提供了完全离线的本地高性能替代方案：

| 维度 | **Piper (本地容器)** | **云端商用 TTS (Azure / OpenAI / 阿里)** |
| :--- | :--- | :--- |
| **成本** | **100% 免费开源**，无调用次数与流量费用 | 按字符数计费，高并发业务账单昂贵 |
| **网络与隐私** | **完全离线本地运行**，无需外网，文本数据不出内网 | 文本需上传至公网厂商服务器，存在合规风险 |
| **生成延迟** | **极低延迟 (RTF < 0.1)**，CPU 上毫秒级出流 | 受网络往返延迟 (RTT) 影响，首字包延迟较高 |
| **资源消耗** | **极度轻量 (~150MB 镜像)**，内存仅需约 80MB~150MB | 本地无需模型，但强依赖公网出口稳定性 |
| **硬件要求** | **纯 CPU 运行**，无需显卡，单核 CPU 即可轻松驱动 | 无本地硬件要求 |

---

## 🏛️ 系统集成架构

```text
┌──────────────────────────────────────────────────────────────────────────────────┐
│                            1. 业务调用方 (Client Layer)                          │
├──────────────────────────────────────────────────────────────────────────────────┤
│  • PHP / Laravel 业务系统 (订单语音播报、通知提醒、有声读物生成)                  │
│  • Home Assistant / 智能家居中枢 (语音设备交互提醒)                              │
│  • Python / Node.js AI 智能体 Agent (将 LLM 对话流实时转换为语音输出)             │
└────────────────────────────────────────┬─────────────────────────────────────────┘
                                         │
                                         │ 1. 发送待合成文本 (Wyoming 协议 / TCP Socket)
                                         ▼
┌──────────────────────────────────────────────────────────────────────────────────┐
│                    2. 端口与网络接入层 (Port & Network Layer)                    │
├──────────────────────────────────────────────────────────────────────────────────┤
│  • 宿主机端口映射: 10200 -> piper:10200                                          │
│  • 内部微服务通信网络: backend (直接通过 piper:10200 互联)                       │
└────────────────────────────────────────┬─────────────────────────────────────────┘
                                         │
                                         │ 2. 调度执行
                                         ▼
┌──────────────────────────────────────────────────────────────────────────────────┐
│                        3. Wyoming Piper 语音合成引擎                             │
│                         (rhasspy/wyoming-piper:2.4.3)                            │
├──────────────────────────────────────────────────────────────────────────────────┤
│  • Wyoming 通信协议事件处理与分帧管理                                            │
│  • 音素转换 (Phonemizer / 拼音与拼读规则分词)                                    │
│  • VITS 神经声码器 ONNX 模型推理 (zh_CN-huayan-medium / zh_CN / en_US 等)        │
│  • 实时生成 22050Hz / 16-bit 单声道 WAV 音频流                                   │
└────────────────────────────────────────┬─────────────────────────────────────────┘
                                         │
                                         │ 3. 持久化缓存语音权重
                                         ▼
┌──────────────────────────────────────────────────────────────────────────────────┐
│                        4. 本地持久化存储挂载 (Data Volume)                       │
│             ${DATA_PATH}piper/data -> /data (自动下载并缓存语音模型)              │
└──────────────────────────────────────────────────────────────────────────────────┘
```

---

## 🔊 发音人与语音模型 (Voice Models)

Piper 镜像采用按需自拉取机制：容器初次启动时，若检测到 `/data` 下不存在指定的语音模型，会自动从官方 Hugging Face 仓库高速下载并缓存，后续重启均直接加载本地模型。

默认配置为中文发音人：**`zh_CN-huayan-medium`**（华严女声，发音清晰自然，非常适合客服、导航与通知提示音）。

常用推荐模型：

| 模型代码 (`PIPER_VOICE`) | 语言 | 风格 / 质量 | 说明 |
| :--- | :--- | :--- | :--- |
| **`zh_CN-huayan-medium`** (默认) | 中文普通话 | 中等质量 (Medium) 女声 | 清晰流利、通用客服播报首选 |
| **`en_US-lessac-medium`** | 英文 (美式) | 中等质量 (Medium) 女声 | 英文发音清晰度极高，适合双语混合 |
| **`en_US-amy-medium`** | 英文 (美式) | 活泼自然女声 | 适合对话交互 |

---

## 🚀 快速上手与验证

### 1. 启动服务

本服务在 `media/docker-compose.yml` 中支持按需引入，也可直接单独启动：

```bash
# 启动 Piper 语音合成服务
docker compose -f media/piper/docker-compose.yml up -d
```

### 2. 客户端调用测试 (Python Wyoming 官方客户端)

Piper 原生基于开放的 [Wyoming 协议](https://github.com/rhasspy/wyoming)。可以通过 Python 快速测试：

```bash
# 安装轻量 Wyoming 客户端工具
pip install wyoming-piper

# 命令行直连测试，合成一段中文并保存为 output.wav
python3 -m wyoming_piper.client \
  --uri "tcp://127.0.0.1:10200" \
  --voice "zh_CN-huayan-medium" \
  --text "您好，您的外卖订单已被骑手接单，预计二十分钟后送达。" > output.wav
```

---

## 🐘 PHP / Laravel 业务接入建议

由于 Piper 核心容器使用高效的 Wyoming 二进制分帧协议进行流式传输，在 PHP/Laravel 生态中，推荐通过以下两种方式调用：

### 方式 A：编写轻量 Python 脚本或 CLI 命令通过进程管道驱动

在 Laravel 命令行或后台 Job 中，通过 `Process` 门面调用 `wyoming-piper` 客户端：

```php
<?php

namespace App\Services;

use Illuminate\Support\Facades\Process;
use Illuminate\Support\Facades\Storage;

class TtsService
{
    /**
     * 将文本合成为音频文件并持久化到本地或 S3
     */
    public function synthesize(string $text, string $outputFileName): string
    {
        $outputPath = storage_path("app/public/{$outputFileName}");
        $host = config('services.piper.host', '127.0.0.1');
        $port = config('services.piper.port', 10200);

        $command = [
            'python3', '-m', 'wyoming_piper.client',
            '--uri', "tcp://{$host}:{$port}",
            '--text', $text,
        ];

        $process = Process::run($command);

        if ($process->successful()) {
            file_put_contents($outputPath, $process->output());
            return $outputPath;
        }

        throw new \RuntimeException('TTS 语音合成失败: ' . $process->errorOutput());
    }
}
```

### 方式 B：搭配轻量 HTTP Gateway（如需要纯 REST API）

如果业务强制需要以 `POST /tts` 的 HTTP JSON 接口方式调用，可随时在 `media/piper/` 目录添加一个不到 30 行代码的 FastAPI 代理边车，将 HTTP 请求直接转为 Wyoming TCP 响应。

---

## ⚙️ 环境变量与配置说明

| 环境变量 | 默认值 | 说明 |
| :--- | :--- | :--- |
| `PIPER_PORT` | `10200` | 宿主机映射的 Wyoming TCP 协议端口 |
| `PIPER_VOICE` | `zh_CN-huayan-medium` | 默认启用的发音人模型名称 |
| `DATA_PATH` | `./data/` | 宿主机持久化目录主路径，模型下载保存在 `${DATA_PATH}piper/data` |
