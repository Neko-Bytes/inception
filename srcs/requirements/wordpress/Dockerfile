FROM debian:bookworm-slim

# Install PHP-FPM, WordPress dependencies, and MariaDB client.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    php8.2-fpm php8.2-mysql php8.2-curl \
    php8.2-xml php8.2-mbstring php8.2-gd php8.2-zip \
    mariadb-client curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Install WP-CLI, the official WordPress command-line tool.
RUN curl -fsSL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    -o /usr/local/bin/wp && \
    chmod +x /usr/local/bin/wp

# Let PHP-FPM accept connections from NGINX over the Docker network.
RUN sed -i 's|^listen = .*|listen = 9000|' \
    /etc/php/8.2/fpm/pool.d/www.conf

# Copy our startup script.
COPY tools/setup.sh /usr/local/bin/setup.sh
RUN chmod +x /usr/local/bin/setup.sh

WORKDIR /var/www/html

ENTRYPOINT ["/usr/local/bin/setup.sh"]
