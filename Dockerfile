FROM wordpress:apache

LABEL com.lullabies.vendor="Lullabies"
LABEL com.lullabies.version="1.0"
LABEL com.lullabies.description="Base image containing Apache 2.4, PHP 7.2, MySQL Client, cURL and Nano editor"

ENV WEB_ROOT_DIR="/var/www/html"
ENV WORDPRESS_LANG="pt_BR"

COPY ./docker-entrypoint/docker-entrypoint.sh /start

COPY ./docker-entrypoint/apache/000-default.conf /etc/apache2/sites-available/000-default.conf
COPY ./docker-entrypoint/apache/apache2-foreground.sh /usr/bin/apache2-foreground

COPY ./docker-entrypoint/wordpress/.htaccess /tmp/.htaccess

RUN apt-get update -y && apt-get install -y \
    mysql-client \
    curl \
    nano \
 && rm -rf /var/lib/apt/lists/*

RUN curl -o /usr/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar

RUN chmod a+x /usr/bin/wp
RUN chmod a+x /start
RUN chmod a+x /usr/bin/apache2-foreground

EXPOSE 80 443

CMD ["/bin/bash", "/start"]