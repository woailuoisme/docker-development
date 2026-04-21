ARG GARAGE_VERSION=v2.3.0
FROM dxflrs/garage:${GARAGE_VERSION}

# Copy configuration (optional as it's often mounted, but good for self-contained image)
COPY garage.toml /etc/garage.toml

# Healthcheck
HEALTHCHECK --interval=30s --timeout=5s --retries=3 --start-period=20s \
  CMD ["/garage", "-c", "/etc/garage.toml", "status"]

# Default command
ENTRYPOINT ["/garage"]
CMD ["server", "--single-node", "--default-bucket"]
