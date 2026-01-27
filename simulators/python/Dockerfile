FROM python:3.12-slim
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

WORKDIR /app

# Sync dependencies using uv
COPY pyproject.toml .
RUN uv sync --no-dev

# Copy source
COPY . .

# Default Envs
ENV MQTT_HOST=mosquitto \
    MQTT_PORT=1883

# Run the simulator
CMD ["uv", "run", "vm_simulator.py"]
