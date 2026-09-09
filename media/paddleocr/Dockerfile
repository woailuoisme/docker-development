ARG PYTHON_VERSION=3.11-slim
FROM python:${PYTHON_VERSION}
LABEL maintainer="seaside <531773730@qq.com>"

ENV PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai

WORKDIR /app

# 安装 ONNXRuntime 运行所需的 libgomp1 及 RapidOCR API (基于 PP-OCRv4 与 FastAPI)
# 使用 opencv-python-headless 避免桌面 X11 GUI 依赖，减小镜像体积至 ~300MB
RUN apt-get update && \
    apt-get install -y --no-install-recommends libgomp1 && \
    rm -rf /var/lib/apt/lists/* && \
    pip install --no-cache-dir \
    rapidocr_api \
    onnxruntime \
    opencv-python-headless && \
    pip uninstall -y opencv-python 2>/dev/null || true

EXPOSE 5000

CMD ["rapidocr_api", "-ip", "0.0.0.0", "-p", "5000", "-workers", "2"]
