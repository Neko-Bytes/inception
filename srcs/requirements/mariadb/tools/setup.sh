#!/bin/sh
set -eu

DATA_DIR=/var/lib/mysql
SOCKET=/run/mysqld/mysqld.sock

# Read passwords from Docker secrets.
DB_PASS=$(cat /run/secrets/db_password)
ROOT_PASS=$(cat /run/secrets/db_root_password)

# Prepare MariaDB directories.
mkdir -p "$DATA_DIR" /run/mysqld
chown -R mysql:mysql "$DATA_DIR" /run/mysqld

# Initialize MariaDB system tables only once.
if [ ! -d "$DATA_DIR/mysql" ]; then
    mariadb-install-db --user=mysql --datadir="$DATA_DIR"
fi

# Configure WordPress database if setup was not completed.
if [ ! -f "$DATA_DIR/.inception-ready" ]; then
    echo "Configuring MariaDB..."

    # Start a temporary server without network access.
    mariadbd --user=mysql --skip-networking --socket="$SOCKET" &
    pid=$!

    # Wait for MariaDB to start.
    attempts=0
    until MYSQL_PWD="$ROOT_PASS" mariadb -u root --socket="$SOCKET" \
        -e "SELECT 1" >/dev/null 2>&1; do
        attempts=$((attempts + 1))

        if [ "$attempts" -ge 30 ]; then
            echo "MariaDB failed to start." >&2
            kill "$pid" 2>/dev/null || true
            exit 1
        fi

        sleep 1
    done

    # Create the WordPress database and user.
    MYSQL_PWD="$ROOT_PASS" mariadb -u root --socket="$SOCKET" <<SQL
CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\`;
CREATE USER IF NOT EXISTS '$MYSQL_USER'@'%' IDENTIFIED BY '$DB_PASS';
ALTER USER '$MYSQL_USER'@'%' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON \`$MYSQL_DATABASE\`.* TO '$MYSQL_USER'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '$ROOT_PASS';
SQL

    # Stop the temporary server.
    kill -TERM "$pid"
    wait "$pid"

    # Record that setup completed successfully.
    touch "$DATA_DIR/.inception-ready"

    echo "MariaDB setup complete."
fi

# Run MariaDB normally.
exec mariadbd --user=mysql --socket="$SOCKET"
