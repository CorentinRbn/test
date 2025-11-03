# DVWA web container based on Debian with Apache + PHP
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# Install Apache, PHP and required extensions, plus utilities
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        apache2 \
        ca-certificates \
        curl \
        libapache2-mod-php \
        php \
        php-gd \
        php-mbstring \
        php-mysqli \
        php-xml \
        php-zip \
        php-curl \
        tini \
    && rm -rf /var/lib/apt/lists/*

# Download DVWA source code
RUN curl -fsSL https://github.com/digininja/DVWA/archive/refs/heads/master.tar.gz -o /tmp/dvwa.tar.gz \
    && mkdir -p /var/www/html \
    && tar -xzf /tmp/dvwa.tar.gz -C /tmp \
    && rm -rf /var/www/html/* \
    && mv /tmp/DVWA-master /var/www/html/dvwa \
    && rm /tmp/dvwa.tar.gz \
    && chown -R www-data:www-data /var/www/html/dvwa

# Apache configuration
COPY apache-vhost.conf /etc/apache2/sites-available/000-default.conf

RUN a2enmod rewrite \
    && chown -R www-data:www-data /var/www/html \
    && find /var/www/html -type d -exec chmod 755 {} + \
    && find /var/www/html -type f -exec chmod 644 {} +

# Entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80

WORKDIR /var/www/html

ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
CMD ["apache2ctl", "-D", "FOREGROUND"]
