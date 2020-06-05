FROM php:7.4.4-fpm-alpine3.11

# Install dev dependencies
RUN apk add --no-cache --virtual .build-deps \
    $PHPIZE_DEPS \
    curl-dev \
    imagemagick-dev \
    libtool \
    libxml2-dev \
    postgresql-dev

# Install production dependencies
RUN apk add --no-cache \
    bash \
    curl \
    freetype-dev \
    g++ \
    gcc \
    git \
    imagemagick \
    libc-dev \
    libjpeg-turbo-dev \
    libpng-dev \
    libzip-dev \
    make \
    oniguruma-dev \
    openssh-client \
    postgresql-libs \
    postgresql-client \
    rsync \
    zlib-dev \
    openssl \
    ca-certificates \
    supervisor

# Install PECL and PEAR extensions
RUN pecl install \
    imagick \
    xdebug

# Enable PECL and PEAR extensions
RUN docker-php-ext-enable \
    imagick \
    xdebug

# Configure php extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg

# Install php extensions
RUN docker-php-ext-install \
    bcmath \
    calendar \
    curl \
    exif \
    gd \
    iconv \
    mbstring \
    pdo \
    pdo_pgsql \
    pcntl \
    tokenizer \
    xml \
    zip

# Install composer
RUN curl -s https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin/ --filename=composer

# Install PHP_CodeSniffer
RUN composer global require "squizlabs/php_codesniffer=*"

# Setup working directory
WORKDIR /var/www/html

COPY . .

# Install Nginx
RUN printf "%s%s%s\n" \
        "http://nginx.org/packages/mainline/alpine/v" \
        `egrep -o '^[0-9]+\.[0-9]+' /etc/alpine-release` \
        "/main" \
        | tee -a /etc/apk/repositories && \
        curl -o /tmp/nginx_signing.rsa.pub https://nginx.org/keys/nginx_signing.rsa.pub && \
        openssl rsa -pubin -in /tmp/nginx_signing.rsa.pub -text -noout && \
        mv /tmp/nginx_signing.rsa.pub /etc/apk/keys/ && \
        apk add nginx && \
        chown -R www-data:www-data /var/log/nginx && \
        chown -R www-data:www-data /var/www/html && \
	mv nginx.conf /etc/nginx/nginx.conf

# Install Brotli
RUN apk add --update --no-cache git bash curl make build-base pcre-dev zlib-dev \
    && mkdir ~/brotli && command="nginx -v" && nginxv=$( ${command} 2>&1 ) && nginxlocal=$(echo $nginxv | grep -o '[0-9.]*$') \
    && cd ~/brotli && curl -L "https://nginx.org/download/nginx-$(echo $nginxlocal).tar.gz" -o nginx.tar.gz && tar zxvf nginx.tar.gz && rm nginx.tar.gz \
    && git clone https://github.com/google/ngx_brotli.git && cd ngx_brotli && git submodule update --init \
    && cd ~/brotli/nginx-$(echo $nginxlocal) && ./configure --with-compat --add-dynamic-module=../ngx_brotli && make modules \
    && cp -r ./objs/*.so /usr/lib/nginx/modules/ \
    && rm -rf ~/brotli/ \
    && sed -i '1iload_module modules/ngx_http_brotli_filter_module.so; load_module modules/ngx_http_brotli_static_module.so;' /etc/nginx/nginx.conf

# Configure Supervisor
RUN mv supervisord.conf /etc/supervisord.conf

# Cleanup dev dependencies
RUN apk del -f .build-deps

# Entrypoint Script
RUN mv start-container /usr/local/bin/start-container && \
    chmod +x /usr/local/bin/start-container

# Expose Nginx Port
EXPOSE 8080

# Switch User
USER www-data

ENTRYPOINT [ "start-container" ]

# Configure a healthcheck to validate that everything is up&running
HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1:8080/fpm-ping
