FROM neilpang/acme.sh:3.1.4

LABEL maintainer="seaside <531773730@qq.com>"

COPY startup.sh /entry.sh
RUN chmod +x /entry.sh

ENTRYPOINT ["/entry.sh"]
