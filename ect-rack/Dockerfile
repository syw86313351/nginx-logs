FROM php:7.4-apache

RUN apt-get update && apt-get install -y \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libldap2-dev \
    libxml2-dev \
    libcurl4-openssl-dev \
    libonig-dev \
    libzip-dev \
    libsnmp-dev \
    snmp \
    && rm -rf /var/lib/apt/lists/*

RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    gd \
    ldap \
    mysqli \
    pdo \
    pdo_mysql \
    mbstring \
    xml \
    curl \
    zip \
    bcmath \
    snmp

RUN a2enmod rewrite

RUN { \
    echo 'upload_max_filesize = 64M'; \
    echo 'post_max_size = 64M'; \
    echo 'max_execution_time = 300'; \
    echo 'memory_limit = 256M'; \
    echo 'date.timezone = Asia/Shanghai'; \
} > /usr/local/etc/php/conf.d/racktables.ini

WORKDIR /var/www/html

COPY RackTables-0.22.0.tar.gz /tmp/
RUN tar -xzf /tmp/RackTables-0.22.0.tar.gz -C /tmp \
    && cp -r /tmp/RackTables-0.22.0/wwwroot/* /var/www/html/ \
    && rm -rf /tmp/RackTables-0.22.0 /tmp/RackTables-0.22.0.tar.gz

RUN mkdir -p cache \
    && chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html

COPY entrypoint.sh /entrypoint.sh
COPY auto-init.php /auto-init.php
RUN chmod +x /entrypoint.sh

EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]
CMD ["apache2-foreground"]