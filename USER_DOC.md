# User Documentation

This document explains how to use the Inception stack: what it provides, how to start and stop it, how to access the website, where the credentials are, and how to check that everything works. All commands are run from the root of the repository.

## 1. Services provided

| Service | What it provides | How you reach it |
|---|---|---|
| NGINX | The secure entry point. Serves the website over HTTPS. | `https://kmummadi.42.fr` (port 443) |
| WordPress | The website and its administration panel. | Through NGINX only |
| MariaDB | The database behind WordPress. | Only from inside the Docker network, or with `docker exec` |

Only port 443 is open to the outside. Plain HTTP (port 80) is not available.

## 2. Starting and stopping

The first time, the configuration files must exist (see section 4). Then:

| Command | Effect |
|---|---|
| `make` | Builds the images if needed and starts the three containers. |
| `make down` | Stops and removes the containers. The website and the database are kept. |
| `make` (again) | Starts everything again with the existing data. |
| `make clean` | Stops the containers and removes the images. Data is kept. |
| `make fclean` | Removes everything, including all website and database data. Asks for the `sudo` password. |

The containers restart automatically after a crash or a reboot of the machine.

## 3. Accessing the website and the administration panel

1. Make sure `/etc/hosts` contains the line `127.0.0.1 kmummadi.42.fr`.
2. Open `https://kmummadi.42.fr` in the browser of the virtual machine.
3. The browser shows a security warning because the certificate is self-signed. Accept it to continue. The connection is still encrypted.
4. The administration panel is at `https://kmummadi.42.fr/wp-admin`. Log in with the administrator account (section 4).

## 4. Credentials

### Where they are

| What | Location |
|---|---|
| User names, e-mail addresses, database name, domain | `srcs/.env` |
| Database user password | `secrets/db_password.txt` |
| Database root password | `secrets/db_root_password.txt` |
| WordPress administrator password | `secrets/wp_admin_password.txt` |
| WordPress second user password | `secrets/wp_user_password.txt` |

These files are not part of the Git repository. They are created on each machine from the examples:

```sh
cp srcs/.env.example srcs/.env
cp -r secrets.example secrets
```

Then write one password in each file of `secrets/`, replacing the placeholder text.

### Accounts

| Account | User name | Password file |
|---|---|---|
| WordPress administrator | `WP_ADMIN_USER` in `srcs/.env` | `wp_admin_password.txt` |
| WordPress second user (author) | `WP_USER` in `srcs/.env` | `wp_user_password.txt` |
| Database user used by WordPress | `MYSQL_USER` in `srcs/.env` | `db_password.txt` |
| Database administrator | `root` | `db_root_password.txt` |

To display a password: `cat secrets/wp_admin_password.txt`

### Changing credentials

**Database passwords** (`db_password.txt`, `db_root_password.txt`): edit the file in `secrets/`, then run `make`. MariaDB and WordPress apply the new value when they start.

**WordPress passwords** are stored in the WordPress database when the site is installed. Editing the files in `secrets/` afterwards does not change them. To change a WordPress password, use one of these methods:

- In the administration panel: log in at `https://kmummadi.42.fr/wp-admin`, open **Users**, choose the user, click **Set New Password** under *Account Management*, then **Update User** (or **Update Profile** for your own account).
- From the command line: `docker exec wordpress wp user update writer --user_pass=NEW_PASSWORD --allow-root`
- By reinstalling: put the new passwords in `secrets/`, then run `make fclean` and `make`. This deletes all website content.

If you change a password in the panel or on the command line, also write it in the matching file in `secrets/`, so the file stays the reference.

### Managing users

The administrator can add, edit and remove accounts in the administration panel under **Users**. WordPress roles determine what an account can do: an *Administrator* manages the whole site, an *Author* writes and publishes posts and comments, a *Subscriber* can only comment and edit their profile.

## 5. Checking that the services run correctly

| Check | Command | Expected result |
|---|---|---|
| Containers are running | `docker compose -f srcs/docker-compose.yml ps` | `nginx`, `wordpress` and `mariadb` are `Up`; `mariadb` is `(healthy)` |
| The website answers over HTTPS | `curl -kI https://kmummadi.42.fr` | `HTTP/1.1 200 OK` |
| Plain HTTP is refused | `curl -I http://kmummadi.42.fr` | Connection refused |
| WordPress users exist | `docker exec wordpress wp user list --allow-root` | The administrator and the author |
| The database is reachable | `docker exec -it mariadb mariadb -u root -p` | A `MariaDB [(none)]>` prompt after typing the root password |
| Logs of a service | `docker logs nginx` (or `wordpress`, `mariadb`) | No error in the last lines |

In the browser, the site at `https://kmummadi.42.fr` must show the WordPress home page, not an installation page, and you must be able to log in at `/wp-admin`.

## 6. If something does not work

| Problem | What to do |
|---|---|
| The browser cannot find `kmummadi.42.fr` | Check that `/etc/hosts` contains `127.0.0.1 kmummadi.42.fr`. |
| `make` reports that a secret file is not found | Create `secrets/` from `secrets.example/` (section 4). |
| `make` reports missing variables | Create `srcs/.env` from `srcs/.env.example` (section 4). |
| A container keeps restarting | Run `docker logs <container>` and read the last lines. A wrong database password or a missing setting is the usual cause. |
| The page shows "502 Bad Gateway" | NGINX cannot reach WordPress. Check that the `wordpress` container is running with `docker compose -f srcs/docker-compose.yml ps`. |
| You are logged out after a restart | This is expected: WordPress gets new login keys at each start. Log in again. |
| Nothing else helps | Run `make re`. This reinstalls everything from scratch and deletes all website content. |
