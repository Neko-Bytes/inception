# WordPress + php-fpm image (no nginx here, nginx has its own container)
#
# What it does:
#   1. starts from Debian 12 "bookworm" (the penultimate stable Debian)
#   2. installs php-fpm (runs the PHP code of WordPress) and the PHP
#      module that lets WordPress talk to MariaDB
#   3. installs WP-CLI, the official command-line tool for WordPress
#   4. makes php-fpm listen on port 9000 so nginx can reach it
#   5. adds our start script
#
# Sources:
#   Dockerfile reference:  https://docs.docker.com/reference/dockerfile/
#   Installing WP-CLI:     https://make.wordpress.org/cli/handbook/guides/installing/
#   php-fpm "listen":      https://www.php.net/manual/en/install.fpm.configuration.php

FROM debian:bookworm

# php8.2-fpm  = PHP for web servers (it also pulls in the php command line)
# php8.2-mysql = lets PHP connect to MariaDB
# curl + ca-certificates = to download WP-CLI over https
RUN apt-get update && apt-get install -y php8.2-fpm php8.2-mysql curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# WP-CLI is a single file; we save it as the command "wp"
RUN curl -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x /usr/local/bin/wp

# by default php-fpm listens on a socket file, which only works inside this container.
# nginx is in another container, so we switch it to port 9000 on the docker network.
RUN sed -i 's|^listen = .*|listen = 9000|' /etc/php/8.2/fpm/pool.d/www.conf

# php-fpm writes its pid file here and doesn't create the folder itself
RUN mkdir -p /run/php

COPY tools/setup.sh /setup.sh
RUN chmod +x /setup.sh

# WordPress files go here (this folder is the wordpress volume)
WORKDIR /var/www/html

ENTRYPOINT ["/setup.sh"]
