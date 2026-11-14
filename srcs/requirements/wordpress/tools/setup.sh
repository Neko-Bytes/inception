#!/bin/sh
set -eu

cd /var/www/html

# Read passwords from Docker secrets.
DB_PASS=$(cat /run/secrets/db_password)
ADMIN_PASS=$(cat /run/secrets/wp_admin_password)
USER_PASS=$(cat /run/secrets/wp_user_password)

# Wait until MariaDB accepts connections.
attempts=0
until MYSQL_PWD="$DB_PASS" mariadb \
    -h mariadb -u "$MYSQL_USER" "$MYSQL_DATABASE" \
    -e "SELECT 1" >/dev/null 2>&1; do

    attempts=$((attempts + 1))
    if [ "$attempts" -ge 30 ]; then
        echo "Cannot connect to MariaDB." >&2
        exit 1
    fi
    sleep 2
done

# Download WordPress only if its files are missing.
if [ ! -f wp-includes/version.php ]; then
    wp core download --allow-root
fi

# Configure the database connection only once.
if [ ! -f wp-config.php ]; then
    wp config create --allow-root \
        --dbname="$MYSQL_DATABASE" \
        --dbuser="$MYSQL_USER" \
        --dbpass="$DB_PASS" \
        --dbhost=mariadb
fi

# Install WordPress and create the administrator.
if ! wp core is-installed --allow-root; then
    wp core install --allow-root \
        --url="https://$DOMAIN_NAME" \
        --title="$WP_TITLE" \
        --admin_user="$WP_ADMIN_USER" \
        --admin_password="$ADMIN_PASS" \
        --admin_email="$WP_ADMIN_EMAIL"
fi

# Create the second user if it does not exist.
if ! wp user get "$WP_USER" --allow-root >/dev/null 2>&1; then
    wp user create "$WP_USER" "$WP_USER_EMAIL" \
        --role=editor \
        --user_pass="$USER_PASS" \
        --allow-root
fi

# Give the web server access to WordPress files.
chown -R www-data:www-data /var/www/html
chmod 640 /var/www/html/wp-config.php

# Start PHP-FPM as the container's main process.
mkdir -p /run/php
exec php-fpm8.2 -F
