FROM alpine:edge

RUN apk add \
    --update \
    --no-cache \
    --repository http://dl-cdn.alpinelinux.org/alpine/edge/testing \
    mysql-client \
    gnupg \
    tini \
    moreutils \
    py-pip \
    && \
    pip install s3cmd
ADD /entrypoint.sh /
ENTRYPOINT ["/sbin/tini", "/entrypoint.sh"]

