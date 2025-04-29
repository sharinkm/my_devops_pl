# ---------- Stage 1: Build Nginx from source ----------
    FROM alpine:3.18 AS builder

    ENV NGINX_VERSION=1.19.9
    ENV PKG_CONFIG_PATH=/usr/local/lib/pkgconfig
    ENV LD_LIBRARY_PATH=/usr/local/lib
    ENV PATH=/usr/local/nginx/sbin:$PATH
    ENV CFLAGS="-O2 -fPIC"
    ENV CXXFLAGS="-O2 -fPIC"
    
    # Install build dependencies
    RUN apk add --no-cache \
        build-base \
        openssl-dev \
        pcre-dev \
        zlib-dev \
        wget \
        linux-headers
    
    # Download and compile Nginx
    RUN wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz \
        && tar -zxvf nginx-${NGINX_VERSION}.tar.gz \
        && cd nginx-${NGINX_VERSION} \
        && ./configure \
            --prefix=/etc/nginx \
            --sbin-path=/usr/sbin/nginx \
            --conf-path=/etc/nginx/nginx.conf \
            --error-log-path=/var/log/nginx/error.log \
            --http-log-path=/var/log/nginx/access.log \
            --pid-path=/var/run/nginx.pid \
            --lock-path=/var/run/nginx.lock \
            --with-http_ssl_module \
            --with-pcre \
            --with-http_v2_module \
            --without-http_autoindex_module \
            --without-http_ssi_module \
            --without-http_userid_module \
        && make \
        && make install
    
    # ---------- Stage 2: Create minimal runtime image ----------
    FROM alpine:3.18
    
    # Create nginx user
    RUN addgroup -S nginx && adduser -S -G nginx -H -s /sbin/nologin nginx \
        && apk add --no-cache openssl pcre zlib
    
    # Copy compiled Nginx from builder
    COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx
    COPY --from=builder /etc/nginx /etc/nginx
    
    # Create required directories
    RUN mkdir -p /var/cache/nginx /var/log/nginx /etc/nginx/conf.d \
        && chown -R nginx:nginx /var/cache/nginx /var/log/nginx
    
    # Switch to non-root user
    USER nginx
    
    EXPOSE 80
    
    CMD ["nginx", "-g", "daemon off;"]
    
