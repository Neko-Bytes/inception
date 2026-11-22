# Developer Documentation

This document explains how to set up the project from scratch, how it is built and launched, how to manage its containers and volumes, and where its data is stored.

## 1. Setting up the environment from scratch

### Prerequisites

- A Linux virtual machine (the project is developed on Debian).
- `make`, `git` and `sudo`:

```sh
sudo apt-get update && sudo apt-get install -y make git
```

- Docker Engine and the Docker Compose plugin, installed by following the official guide for Debian: https://docs.docker.com/engine/install/debian/ . Check the installation with:

```sh
docker --version
docker compose version
```

- Your user in the `docker` group, so Docker commands run without `sudo` (official post-installation steps: https://docs.docker.com/engine/install/linux-postinstall/):

```sh
sudo usermod -aG docker $USER    # then log out and log in again
```

- The domain pointing to the machine:

```sh
echo "127.0.0.1 kmummadi.42.fr" | sudo tee -a /etc/hosts
```

### Configuration files

```sh
git clone https://github.com/Neko-Bytes/Inception.git inception
cd inception
cp srcs/.env.example srcs/.env
cp -r secrets.example secrets
```

**`srcs/.env`** holds settings that are not confidential. Compose passes every line to the containers as an environment variable (`env_file: .env`).

| Variable | Used by | Meaning |
|---|---|---|
| `DOMAIN_NAME` | wordpress | Address of the site, used at installation |
| `MYSQL_DATABASE` | mariadb, wordpress | Name of the WordPress database |
| `MYSQL_USER` | mariadb, wordpress | Database user that WordPress logs in with |
| `WP_TITLE` | wordpress | Site title |
| `WP_ADMIN_USER`, `WP_ADMIN_EMAIL` | wordpress | Administrator account. The name must not contain "admin" |
| `WP_USER`, `WP_USER_EMAIL` | wordpress | Second account (role: author) |

**`secrets/`** holds one password per file. Compose mounts each file in the containers that declare it, at `/run/secrets/<name>`.

| File | Mounted in | Used for |
|---|---|---|
| `db_password.txt` | mariadb, wordpress | Password of `MYSQL_USER` |
| `db_root_password.txt` | mariadb | Password of the MariaDB `root` user |
| `wp_admin_password.txt` | wordpress | WordPress administrator password |
| `wp_user_password.txt` | wordpress | Second WordPress user password |

Both `srcs/.env` and `secrets/` are listed in `.gitignore` and must never be committed.

## 2. Building and launching

The Makefile wraps Docker Compose:

| Target | Commands run |
|---|---|
| `make` / `make all` | `mkdir -p /home/kmummadi/data/mariadb /home/kmummadi/data/wordpress`, then `docker compose -f srcs/docker-compose.yml up -d --build` |
| `make down` | `docker compose ... down` |
| `make clean` | `docker compose ... down --rmi all` |
| `make fclean` | `clean`, then `docker compose ... down -v` and `sudo rm -rf /home/kmummadi/data` |
| `make re` | `fclean`, then `all` |

`--build` rebuilds an image only when its Dockerfile or copied files changed. `-d` runs the containers in the background.

### Start-up sequence

1. Compose builds `mariadb:inception`, `wordpress:inception` and `nginx:inception` from `srcs/requirements/*/Dockerfile`.
2. Compose creates the network `srcs_inception` and the volumes `srcs_mariadb_data` and `srcs_wordpress_data`.
3. `mariadb` runs `tools/setup.sh`: on the first start it creates the system tables with `mariadb-install-db`. On every start it writes `/tmp/init.sql` (database, user, passwords) and starts `mariadbd --init-file=/tmp/init.sql` as PID 1.
4. The healthcheck (`mariadb-admin ping`, every 5 seconds) marks `mariadb` as healthy once it accepts connections.
5. `wordpress` starts only then. Its `tools/setup.sh` downloads WordPress if the volume is empty, writes `wp-config.php`, installs the site and creates the two users if needed, then starts `php-fpm8.2 -F` as PID 1.
6. `nginx` starts in the foreground (`daemon off;`) and listens on port 443.

### Project files

| File | Purpose |
|---|---|
| `srcs/docker-compose.yml` | Services, volumes, network and secrets |
| `srcs/requirements/mariadb/Dockerfile` | Installs `mariadb-server`, copies the config and the start script |
| `srcs/requirements/mariadb/conf/server.cnf` | Sets `port = 3306` and `bind-address = 0.0.0.0` |
| `srcs/requirements/mariadb/tools/setup.sh` | Initialises and starts MariaDB |
| `srcs/requirements/wordpress/Dockerfile` | Installs PHP-FPM, the MySQL module and WP-CLI; sets PHP-FPM to listen on port 9000 |
| `srcs/requirements/wordpress/tools/setup.sh` | Downloads, configures and installs WordPress, then starts PHP-FPM |
| `srcs/requirements/nginx/Dockerfile` | Installs NGINX and OpenSSL, generates the self-signed certificate |
| `srcs/requirements/nginx/conf/default.conf` | HTTPS server on 443, TLSv1.2/1.3, FastCGI to `wordpress:9000` |

## 3. Managing containers and volumes

All commands are run from the repository root. In the tables, `dc` stands for `docker compose -f srcs/docker-compose.yml`.

### 3.1 Containers

| Task | Command |
|---|---|
| List the project's containers and their state | `dc ps` |
| Stop the containers without removing them | `dc stop` |
| Start stopped containers again | `dc start` |
| Restart one service | `dc restart wordpress` |
| Rebuild and restart one service after editing its files | `dc up -d --build nginx` |
| Follow the logs of all services | `dc logs -f` |
| Show the last lines of one service's log | `docker logs --tail 50 mariadb` |
| Open a shell inside a container | `docker exec -it wordpress bash` |
| Show the health status of MariaDB | `docker inspect --format '{{.State.Health.Status}}' mariadb` |
| Show which program runs as PID 1 | `docker exec mariadb cat /proc/1/comm` (expected: `mariadbd`; `php-fpm8.2` in `wordpress`, `nginx` in `nginx`) |
| Show the environment variables of a container | `docker exec wordpress env` |
| Show the secrets mounted in a container | `docker exec wordpress ls -l /run/secrets` |
| List the project's images | `docker image ls` (`mariadb:inception`, `wordpress:inception`, `nginx:inception`) |

### 3.2 Volumes and network

| Task | Command |
|---|---|
| List volumes | `docker volume ls` |
| Show where a volume stores its data | `docker volume inspect srcs_wordpress_data` (field `device`) |
| Look at the data on the host | `sudo ls -l /home/kmummadi/data/mariadb /home/kmummadi/data/wordpress` |
| Remove the volumes (containers must be removed first) | `dc down -v` |
| List networks | `docker network ls` |
| Show the containers connected to the network | `docker network inspect srcs_inception` |

### 3.3 MariaDB

MariaDB is managed with the `mariadb` client inside the `mariadb` container. The passwords are in `secrets/db_root_password.txt` and `secrets/db_password.txt`.

| Task | Command |
|---|---|
| Open a SQL session as root | `docker exec -it mariadb mariadb -u root -p` |
| Open a SQL session as the WordPress user | `docker exec -it mariadb mariadb -u wpuser -p wordpress` |
| Run one SQL statement without an interactive session | `docker exec -it mariadb mariadb -u root -p -e "SHOW DATABASES;"` |
| Show the server status | `docker exec -it mariadb mariadb-admin -u root -p status` |
| Check that root cannot log in without a password | `docker exec -it mariadb mariadb -u root` (expected: `Access denied`) |

Useful SQL statements, once logged in:

```sql
SHOW DATABASES;                                  -- wordpress, plus MariaDB's own system databases
SELECT user, host FROM mysql.user;               -- root, mysql and the WordPress user
USE wordpress;
SHOW TABLES;                                     -- the wp_ tables created by WordPress
SELECT ID, user_login, user_email FROM wp_users; -- the two WordPress accounts
SELECT comment_author, comment_content FROM wp_comments;
SELECT option_name, option_value FROM wp_options WHERE option_name IN ('siteurl', 'home');
EXIT;
```

Backup and restore of the WordPress database (the password is read from the secret inside the container, so it never appears on the command line of the host):

```sh
docker exec mariadb sh -c 'mariadb-dump -u root -p"$(cat /run/secrets/db_root_password)" wordpress' > backup.sql
docker exec -i mariadb sh -c 'mariadb -u root -p"$(cat /run/secrets/db_root_password)" wordpress' < backup.sql
```

### 3.4 WordPress (WP-CLI)

WP-CLI is installed in the `wordpress` container as the command `wp`. Commands run there as root, so each one needs `--allow-root`. Command reference: https://developer.wordpress.org/cli/commands/

| Task | Command |
|---|---|
| Show the WordPress version | `docker exec wordpress wp core version --allow-root` |
| Check that WordPress is installed | `docker exec wordpress wp core is-installed --allow-root && echo installed` |
| List the users and their roles | `docker exec wordpress wp user list --fields=ID,user_login,roles --allow-root` |
| Create a user | `docker exec wordpress wp user create alice alice@example.com --role=author --user_pass=CHOSEN_PASSWORD --allow-root` |
| Change a user's password | `docker exec wordpress wp user update writer --user_pass=NEW_PASSWORD --allow-root` |
| Delete a user and give their posts to user 1 | `docker exec wordpress wp user delete alice --reassign=1 --allow-root` |
| List posts and pages | `docker exec wordpress wp post list --post_type=post,page --allow-root` |
| Create and publish a post | `docker exec wordpress wp post create --post_title="Hello" --post_status=publish --allow-root` |
| List comments | `docker exec wordpress wp comment list --allow-root` |
| Show the site address | `docker exec wordpress wp option get siteurl --allow-root` |
| Change the site address | `docker exec wordpress wp option update home https://kmummadi.42.fr --allow-root` and the same with `siteurl` |
| Show the database host used by WordPress | `docker exec wordpress wp config get DB_HOST --allow-root` |
| List plugins and themes | `docker exec wordpress wp plugin list --allow-root`, `docker exec wordpress wp theme list --allow-root` |

The `wp db ...` commands are not available, because they need a MySQL client that is not installed in the `wordpress` container. Use the `mariadb` container for database work (section 3.3).

Passwords typed on a command line can be kept in the shell history. For lasting changes, prefer the administration panel or edit the files in `secrets/` and reinstall.

### 3.5 NGINX and TLS

| Task | Command |
|---|---|
| Test the NGINX configuration for errors | `docker exec nginx nginx -t` |
| Show the certificate's name and validity dates | `docker exec nginx openssl x509 -in /etc/nginx/ssl/inception.crt -noout -subject -dates` |
| Check that the site answers over HTTPS | `curl -kI https://kmummadi.42.fr` (`-k` accepts the self-signed certificate) |
| Check that plain HTTP is refused | `curl -I http://kmummadi.42.fr` (expected: connection refused) |
| Check that TLS 1.2 is accepted | `openssl s_client -connect kmummadi.42.fr:443 -tls1_2 < /dev/null` |
| Check that TLS 1.1 is refused | `openssl s_client -connect kmummadi.42.fr:443 -tls1_1 < /dev/null` (expected: handshake failure) |

### 3.6 Changing a port

| Port | Defined in | Must match |
|---|---|---|
| 443 (outside) | `docker-compose.yml`, left side of `"443:443"` | After a change, update the WordPress address with `wp option update home` and `wp option update siteurl` |
| 443 (inside nginx) | `nginx/conf/default.conf`, `listen 443 ssl;` | Right side of `"443:443"` |
| 9000 (PHP-FPM) | `wordpress/Dockerfile`, `listen = 9000` | `fastcgi_pass wordpress:9000;` in `nginx/conf/default.conf` |
| 3306 (MariaDB) | `mariadb/conf/server.cnf`, `port = 3306` | `--dbhost=mariadb:3306` in `wordpress/tools/setup.sh` |

Run `make` after any change. Example for the outside port:

```sh
docker exec wordpress wp option update home    https://kmummadi.42.fr:8443 --allow-root
docker exec wordpress wp option update siteurl https://kmummadi.42.fr:8443 --allow-root
```

The subject requires port 443; any other value is for testing only.

## 4. Data storage and persistence

| Volume | Mounted at | Stored on the host in | Contents |
|---|---|---|---|
| `srcs_mariadb_data` | `/var/lib/mysql` in `mariadb` | `/home/kmummadi/data/mariadb` | Database files |
| `srcs_wordpress_data` | `/var/www/html` in `wordpress`, read-only in `nginx` | `/home/kmummadi/data/wordpress` | WordPress files, uploads, `wp-config.php` |

Both are Docker named volumes created by the `local` driver with the options `type: none`, `o: bind` and `device: <host directory>`. Docker manages them like any named volume, and their data is kept in the host directory. The Makefile creates these directories because the driver requires them to exist.

### How the data persists

- Removing or rebuilding a container does not touch the volumes.
- On start, `mariadb/tools/setup.sh` initialises the database only if `/var/lib/mysql/mysql` does not exist.
- On start, `wordpress/tools/setup.sh` downloads WordPress only if `wp-load.php` is missing, and installs it only if `wp core is-installed` reports that it is not installed.
- After a reboot, Docker restarts the containers (`restart: unless-stopped`). They find their data and skip the first-time steps.
- Only `make fclean` deletes the volumes and the host directories. After it, the next `make` performs a fresh installation using the current `srcs/.env` and `secrets/`.

### Notes

- `wp-config.php` is rewritten on every start (`wp config create --force`), so a changed database password or port applies after `make`. WordPress also receives new login keys, so users must log in again after a restart.
- After a reboot, Docker may start `wordpress` before `mariadb` is ready. It then exits and is restarted automatically until the database is available.
