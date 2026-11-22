#!/bin/sh
# MariaDB start script (the container's ENTRYPOINT)
#
# What it does:
#   1. reads the passwords that docker gives us from secrets/
#   2. prepares the folders MariaDB needs
#   3. first start only: creates MariaDB's own system tables in the volume
#   4. writes the SQL that creates the WordPress database and user
#   5. starts MariaDB, which runs that SQL while starting up
#
# Sources:
#   mariadb-install-db: https://mariadb.com/docs/server/clients-and-utilities/deployment-tools/mariadb-install-db
#   --init-file:        https://mariadb.com/docs/server/server-management/variables-and-modes/server-system-variables#init_file

# stop the script if any command fails
set -e

# 1. docker puts our secrets/*.txt files in /run/secrets/ inside the container
DB_PASS=$(cat /run/secrets/db_password)
ROOT_PASS=$(cat /run/secrets/db_root_password)

# 2. /run/mysqld holds the socket file (how local programs talk to MariaDB)
mkdir -p /run/mysqld
# MariaDB runs as the "mysql" user, so it must own its folders
chown -R mysql:mysql /run/mysqld /var/lib/mysql

# 3. an empty volume has no "mysql" folder yet -> this is the first start
#    --skip-test-db: no test database and no anonymous (no-name) user
if [ ! -d /var/lib/mysql/mysql ]; then
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql --skip-test-db
fi

# 4. this SQL runs on every start, so every line must be safe to repeat
#    (that's why it says IF NOT EXISTS). '%' = can connect from any container.
cat > /tmp/init.sql << EOF
CREATE DATABASE IF NOT EXISTS $MYSQL_DATABASE;
CREATE USER IF NOT EXISTS '$MYSQL_USER'@'%' IDENTIFIED BY '$DB_PASS';
ALTER USER '$MYSQL_USER'@'%' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $MYSQL_DATABASE.* TO '$MYSQL_USER'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '$ROOT_PASS';
FLUSH PRIVILEGES;
EOF

# 5. exec = MariaDB replaces this script and becomes PID 1,
#    so docker can stop it cleanly and restart it if it crashes
exec mariadbd --user=mysql --init-file=/tmp/init.sql
