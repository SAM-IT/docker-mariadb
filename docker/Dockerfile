FROM mariadb
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*
ENTRYPOINT ["/bin/tini", "--", "/usr/local/bin/docker-entrypoint.sh"]
CMD ["mysqld"]
ENV TINI_VERSION v0.18.0
ENV GIDDYUP_VERSION v0.19.0
RUN gpg --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 595E85A6B1B4779EA4DAAEC70B588DFF0527A9B7

ADD https://github.com/rancher/giddyup/releases/download/${GIDDYUP_VERSION}/giddyup /bin/giddyup
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /bin/tini
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini.asc /bin/tini.asc
RUN gpg --verify /bin/tini.asc \
 && rm /bin/tini.asc \
 && rm -rf /root/.gnupg \
 && chmod +x /bin/tini \
 && chmod +x /bin/giddyup
COPY docker-entrypoint.sh /usr/local/bin/
COPY prepare.sh /prepare.sh
COPY conf.d /etc/mysql/conf.d
COPY healthcheck.sh /usr/local/bin/healthcheck.sh