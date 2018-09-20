FROM alpine:3.8

LABEL maintainer="liubang <it.liubang@gmail.com>"

# Docker Build Arguments
ARG RESTY_VERSION="1.13.6.2"
ARG RESTY_OPENSSL_VERSION="1.0.2k"
ARG RESTY_PCRE_VERSION="8.42"
ARG RESTY_J="1"
ARG CONSUL_TEMPLATE_VERSION="0.19.5"

ARG RESTY_CONFIG_OPTIONS="\
    --with-file-aio \
    --with-http_addition_module \
    --with-http_auth_request_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_geoip_module=dynamic \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_image_filter_module=dynamic \
    --with-http_mp4_module \
    --with-http_random_index_module \
    --with-http_realip_module \
    --with-http_secure_link_module \
    --with-http_slice_module \
    --with-http_ssl_module \
    --with-http_stub_status_module \
    --with-http_sub_module \
    --with-http_v2_module \
    --with-http_xslt_module=dynamic \
    --with-ipv6 \
    --with-mail \
    --with-mail_ssl_module \
    --with-md5-asm \
    --with-pcre-jit \
    --with-sha1-asm \
    --with-stream \
    --with-stream_ssl_module \
    --with-threads \
    "

ARG RESTY_CONFIG_OPTIONS_MORE=""

LABEL resty_version="${RESTY_VERSION}"
LABEL resty_openssl_version="${RESTY_OPENSSL_VERSION}"
LABEL resty_pcre_version="${RESTY_PCRE_VERSION}"
LABEL resty_config_options="${RESTY_CONFIG_OPTIONS}"
LABEL resty_config_options_more="${RESTY_CONFIG_OPTIONS_MORE}"

# These are not intended to be user-specified
ARG _RESTY_CONFIG_DEPS="--prefix=/opt/app/openresty \
                        --sbin-path=/opt/app/nginx/sbin/nginx \
                        --conf-path=/opt/app/nginx/conf/nginx.conf \
                        --http-log-path=/opt/app/nginx/logs/access.log \
                        --error-log-path=/opt/app/nginx/logs/error.log \
                        --lock-path=/opt/app/nginx/logs/nginx.lock \
                        --pid-path=/opt/app/nginx/logs/nginx.pid \
                        --with-openssl=/tmp/openssl-${RESTY_OPENSSL_VERSION} \
                        --with-pcre=/tmp/pcre-${RESTY_PCRE_VERSION} \
                        "

RUN apk add --no-cache --virtual .build-deps \
        build-base \
        curl \
        gd-dev \
        geoip-dev \
        libxslt-dev \
        linux-headers \
        make \
        perl-dev \
        readline-dev \
        zlib-dev \
    && apk add --no-cache \
        gd \
        geoip \
        libgcc \
        libxslt \
        zlib \ 
        supervisor \
        inotify-tools \
    && cd /tmp \
    && curl -fSL https://www.openssl.org/source/openssl-${RESTY_OPENSSL_VERSION}.tar.gz -o openssl-${RESTY_OPENSSL_VERSION}.tar.gz \
    && tar xzf openssl-${RESTY_OPENSSL_VERSION}.tar.gz \
    && curl -fSL https://ftp.pcre.org/pub/pcre/pcre-${RESTY_PCRE_VERSION}.tar.gz -o pcre-${RESTY_PCRE_VERSION}.tar.gz \
    && tar xzf pcre-${RESTY_PCRE_VERSION}.tar.gz \
    && curl -fSL https://openresty.org/download/openresty-${RESTY_VERSION}.tar.gz -o openresty-${RESTY_VERSION}.tar.gz \
    && tar xzf openresty-${RESTY_VERSION}.tar.gz \
    && cd /tmp/openresty-${RESTY_VERSION} \
    && ./configure -j${RESTY_J} ${_RESTY_CONFIG_DEPS} ${RESTY_CONFIG_OPTIONS} ${RESTY_CONFIG_OPTIONS_MORE} \
    && make -j${RESTY_J} \
    && make -j${RESTY_J} install \
    && cd /tmp \
    && rm -rf \
        openssl-${RESTY_OPENSSL_VERSION} \
        openssl-${RESTY_OPENSSL_VERSION}.tar.gz \
        openresty-${RESTY_VERSION}.tar.gz openresty-${RESTY_VERSION} \
        pcre-${RESTY_PCRE_VERSION}.tar.gz pcre-${RESTY_PCRE_VERSION} \
    && apk del .build-deps  

ADD https://releases.hashicorp.com/consul-template/${CONSUL_TEMPLATE_VERSION}/consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.tgz /opt/app/consul-template/bin/consul-template.tgz 

RUN cd /opt/app/consul-template/bin \
    && tar zxf consul-template.tgz  \
    && chmod +x /opt/app/consul-template/bin/consul-template \
    && rm consul-template.tgz \
    && mkdir -p /data/logs/supervisor \
    && ln -sf /dev/stdout /data/logs/supervisor/nginx.log \
    && ln -sf /dev/stdout /data/logs/supervisor/consul-template.log \
    && ln -sf /dev/stderr /data/logs/supervisor/nginx_err.log \
    && ln -sf /dev/stderr /data/logs/supervisor/consul-template_err.log 

# Add additional binaries into PATH for convenience
ENV PATH=$PATH:/opt/app/openresty/luajit/bin:/opt/app/nginx/sbin:/opt/app/openresty/bin:/opt/app/consul-template/bin

COPY supervisord.conf /etc/supervisord.conf
COPY supervisor/conf.d/nginx.conf /etc/supervisor/conf.d/nginx.conf
COPY supervisor/conf.d/consul-template.conf /etc/supervisor/conf.d/consul-template.conf
COPY nginx.conf /opt/app/nginx/conf/nginx.conf
COPY consul-template.hcl /opt/app/consul-template/etc/config.hcl

CMD ["--nodaemon", "-c", "/etc/supervisord.conf"]

ENTRYPOINT ["/usr/bin/supervisord"]
