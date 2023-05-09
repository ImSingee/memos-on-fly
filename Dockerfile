ARG MEMOS_VERSION

FROM alpine:3.16 as litestream-builder

ADD https://github.com/benbjohnson/litestream/releases/download/v0.3.8/litestream-v0.3.8-linux-amd64-static.tar.gz /tmp/litestream.tar.gz
RUN tar -C /usr/local/bin -xzf /tmp/litestream.tar.gz

FROM neosmemo/memos:$MEMOS_VERSION AS memos

FROM alpine:3.16
WORKDIR /usr/local/memos

# Setup timezone
RUN apk add --no-cache tzdata
ENV TZ="UTC"

# Copy litestream
COPY --from=litestream-builder --chmod=+x /usr/local/bin/litestream /usr/local/bin/litestream
COPY litestream.yml /etc/litestream.yml

# Copy memos
COPY --from=memos /usr/local/memos/memos /usr/local/memos/memos 

# Directory to store the data, which can be referenced as the mounting point.
RUN mkdir -p /var/opt/memos

COPY --chmod=+x run.sh /usr/local/memos/run.sh
ENTRYPOINT ["./run.sh"]