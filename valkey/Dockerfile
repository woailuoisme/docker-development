FROM valkey/valkey:8.1-trixie

RUN mkdir -p /usr/local/etc/valkey /data && \
    chown -R valkey:valkey /usr/local/etc/valkey /data

COPY valkey.conf /usr/local/etc/valkey/valkey.conf

COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

WORKDIR /data

EXPOSE 6379

# 设置入口点：处理启动前的逻辑 (如注入密码)
ENTRYPOINT ["docker-entrypoint.sh"]

# 默认启动命令
CMD ["valkey-server", "/usr/local/etc/valkey/valkey.conf"]