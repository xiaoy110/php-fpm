FROM php:7.2-fpm-alpine

ENV BUILD_DEPS tzdata \
    linux-headers \
    libzip-dev \
    libpng-dev \
    curl-dev \
    freetype \
    libjpeg-turbo \
    freetype-dev \
    libjpeg-turbo-dev \
    git

ENV PHPREDIS_VERSION 3.1.3
RUN sed -i -e "s/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g" /etc/apk/repositories \
#RUN sed -i -e "s/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g" /etc/apk/repositories \
    && apk add --no-cache $BUILD_DEPS \
    && apk add --no-cache --virtual .persistent-deps \
        git \
        nginx \
        libzip \
        #zip \
        unzip \
        libpng \
        libjpeg-turbo \
        freetype \
# user & group
    && addgroup -g 3000 -S app \
    && adduser -u 3000 -S -D -G app app \
# build deps
# timezone
    && cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo "Asia/Shanghai" > /etc/timezone \
    && docker-php-source extract \
# configure zip, including install build_deps
    && docker-php-ext-configure zip --with-libzip \
# phpiredis
    && curl -fsSL 'https://github.com/redis/hiredis/archive/v0.13.3.tar.gz' -o hiredis.tar.gz \
    && mkdir -p hiredis \
    && tar -xf hiredis.tar.gz -C hiredis --strip-components=1 \
    && rm hiredis.tar.gz \
    && ( \
        cd hiredis \
        && make -j$(nproc) \
        && make install \
    ) \
    && rm -r hiredis \
    && curl -fsSL 'https://github.com/nrk/phpiredis/archive/v1.0.0.tar.gz' -o phpiredis.tar.gz \
    && mkdir -p phpiredis \
    && tar -xf phpiredis.tar.gz -C phpiredis --strip-components=1 \
    && rm phpiredis.tar.gz \
    && ( \
        cd phpiredis \
        && phpize \
        && ./configure --enable-phpiredis \
        && make -j$(nproc) \
        && make install \
    ) \
    && rm -r phpiredis \
# freetype
   && docker-php-ext-configure gd \
       --with-gd \
       --with-freetype-dir=/usr/include/ \
       --with-png-dir=/usr/include/ \
       --with-jpeg-dir=/usr/include/ \
   nproc=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || 1)  \
# molten
    && git clone --depth=1 https://github.com/chuan-yun/Molten.git /usr/src/php/ext/molten \
    && docker-php-ext-configure molten --enable-zipkin-header=yes \
# exts
    && docker-php-ext-install -j$(nproc) zip pdo_mysql molten bcmath gd\
    && docker-php-source delete \
    && mkdir /run/nginx \
# redis
    && curl -L -o /tmp/redis.tar.gz https://github.com/phpredis/phpredis/archive/$PHPREDIS_VERSION.tar.gz \
    && tar xfz /tmp/redis.tar.gz \
    && rm -r /tmp/redis.tar.gz \
    && mkdir -p /usr/src/php/ext \
    && mv phpredis-$PHPREDIS_VERSION /usr/src/php/ext/redis \
    && docker-php-ext-install redis \
    && rm -rf /usr/src/php \
# composer
#    && php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
#    && php -r "if (hash_file('SHA384', 'composer-setup.php') === '544e09ee996cdf60ece3804abc52599c22b1f40f4323403c44d44fdfdd586475ca9813a858088ffbc1f233e9b180f061') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;" \
#    && php composer-setup.php \
#    && php -r "unlink('composer-setup.php');" \
#    && mv composer.phar /bin/composer \
    && apk del $BUILD_DEPS
#RUN sed -i "s#127.0.0.1:9000#/proc/scsi/php-fpm.sock#" /usr/local/etc/php-fpm.d/www.conf
COPY default.conf /etc/nginx/conf.d
COPY www.conf /usr/local/etc/php-fpm.d
ONBUILD COPY . /var/www/html/webapp
CMD nginx;php-fpm
