# docker build -t yuanying/node-exporter-smartmon .
# docker run --privileged yuanying/node-exporter-smartmon
FROM alpine:latest@sha256:be2656061b536c1883c4034790e21d0a09c5aaaf51968b89368a3c0371ea2c9a
MAINTAINER OTSUKA, Yuanying "yuan-docker@fraction.jp"

COPY smartmon.sh /

RUN apk --no-cache --update add smartmontools bash; \
    rm -rf /var/cache/apk/*; \
    chmod +x /smartmon.sh

ENTRYPOINT ["/smartmon.sh"]
