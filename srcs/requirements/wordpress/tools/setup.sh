#!/bin/sh
# WordPress start script (the container's ENTRYPOINT)
#
# What it does:
#   1. reads the passwords that docker gives us from secrets/
#   2. first start only: downloads WordPress into the volume
#   3. every start: writes wp-config.php (how WordPress logs in to MariaDB)
#   4. first start only: installs the site, creates the admin and the second user
#   5. gives the files to www-data, the user php-fpm runs as
#   6. starts php-fpm, which runs WordPress's PHP code for nginx
#
# On later starts the files and the database are already in the volumes,
# so steps 2 and 4 are skipped. That's what makes the site survive a reboot.
# Step 3 runs every time, so a changed password or port is picked up by `make`.
#
# Sources (WP-CLI commands):
#   wp core download:     https://developer.wordpress.org/cli/commands/core/download/
#   wp config create:     https://developer.wordpress.org/cli/commands/config/create/
#   wp core is-installed: https://developer.wordpress.org/cli/commands/core/is-installed/
#   wp core install:      https://developer.wordpress.org/cli/commands/core/install/
#   wp user create:       https://developer.wordpress.org/cli/commands/user/create/

# stop the script if any command fails
set -e

# 1. docker puts our secrets/*.txt files in /run/secrets/ inside the container
DB_PASS=$(cat /run/secrets/db_password)
ADMIN_PASS=$(cat /run/secrets/wp_admin_password)
USER_PASS=$(cat /run/secrets/wp_user_password)

# --allow-root is needed because this script runs as root inside the container

# 2. no wp-load.php yet = the volume is empty
if [ ! -f wp-load.php ]; then
    wp core download --allow-root
fi

# 3. "mariadb" is the service name, docker's network turns it into the container's address.
#    3306 is MariaDB's port (set in mariadb/conf/server.cnf).
#    --force = overwrite the old wp-config.php, so it always matches .env and secrets/
wp config create --allow-root --force \
    --dbname="$MYSQL_DATABASE" \
    --dbuser="$MYSQL_USER" \
    --dbpass="$DB_PASS" \
    --dbhost=mariadb:3306

# 4. --skip-email: there is no mail server, so don't try to send the welcome email
#    the second user is an "author": can write posts and comments, can't manage the site
if ! wp core is-installed --allow-root; then
    wp core install --allow-root \
        --url="https://$DOMAIN_NAME" \
        --title="$WP_TITLE" \
        --admin_user="$WP_ADMIN_USER" \
        --admin_password="$ADMIN_PASS" \
        --admin_email="$WP_ADMIN_EMAIL" \
        --skip-email

    wp user create "$WP_USER" "$WP_USER_EMAIL" --allow-root \
        --role=author \
        --user_pass="$USER_PASS"
fi

# 5. php-fpm runs as www-data and needs to write here (uploads, plugin updates)
chown -R www-data:www-data /var/www/html

# 6. -F = stay in the foreground. exec = php-fpm replaces this script and becomes PID 1
exec php-fpm8.2 -F
