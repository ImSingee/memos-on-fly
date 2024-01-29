ARG MEMOS_VERSION

FROM alpine:3.16 as litestream-builder

ADD https://github.com/benbjohnson/litestream/releases/download/v0.3.8/litestream-v0.3.8-linux-amd64-static.tar.gz /tmp/litestream.tar.gz
RUN tar -C /usr/local/bin -xzf /tmp/litestream.tar.gz

FROM ghcr.io/usememos/memos:$MEMOS_VERSION
WORKDIR /usr/local/memos

# Copy litestream
COPY --from=litestream-builder --chmod=+x /usr/local/bin/litestream /usr/local/bin/litestream
COPY litestream.yml /etc/litestream.yml

# Directory to store the data, which can be referenced as the mounting point.
RUN mkdir -p /var/opt/memos

COPY --chmod=+x run.sh /usr/local/memos/run.sh
ENTRYPOINT ["./run.sh"]