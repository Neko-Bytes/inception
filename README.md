*This project has been created as part of the 42 curriculum by kmummadi.*

# Inception

## Description

Inception is a system administration project. Its goal is to build a small web infrastructure with Docker, inside a virtual machine, following a strict set of rules.

The infrastructure runs a WordPress website and consists of three services, each in its own container:

| Service | Role | Port |
|---|---|---|
| `nginx` | Web server and the only entry point. Accepts HTTPS connections (TLSv1.2 and TLSv1.3 only). | 443, published |
| `wordpress` | WordPress run by PHP-FPM. Executes the PHP code of the website. | 9000, internal only |
| `mariadb` | Database storing the website's content, users and settings. | 3306, internal only |

A request travels as follows:

```
browser --HTTPS 443--> nginx --FastCGI 9000--> wordpress (php-fpm) --SQL 3306--> mariadb
```

The website is available at `https://kmummadi.42.fr` (local). The database and the website files are stored in two Docker named volumes, kept in `/home/kmummadi/data` on the host, so that all data survives a restart or a reboot.

## Project description

### Use of Docker and sources included

Every image is built from a Dockerfile written for this project, starting from `debian:bookworm` (Debian 12, the penultimate stable Debian release). No ready-made service image is pulled from Docker Hub. Docker Compose describes the three services, the network, the volumes and the secrets, and the Makefile drives Compose.

```
.
├── Makefile                      build, start, stop and clean the project
├── README.md, USER_DOC.md, DEV_DOC.md
├── secrets.example/              placeholder password files (committed)
├── secrets/                      real password files (created locally, ignored by git)
└── srcs/
    ├── .env.example              non-secret settings template (committed)
    ├── .env                      real settings (created locally, ignored by git)
    ├── docker-compose.yml
    └── requirements/
        ├── mariadb/    Dockerfile, conf/server.cnf, tools/setup.sh
        ├── wordpress/  Dockerfile, tools/setup.sh
        └── nginx/      Dockerfile, conf/default.conf
```

### Main design choices

- **Debian 12 (bookworm)** as the base of every image: its package manager and default configuration are widely documented.
- **One start script per service** (`tools/setup.sh`). Each script prepares its service, then replaces itself with the server process using `exec`, so the server runs in the foreground as PID 1. No background processes, infinite loops or `tail -f` are used.
- **MariaDB initialisation with `--init-file`**: the database, the WordPress user and the root password are created by an SQL file that the server runs at startup. Every statement can safely run again, so the same script handles the first start and every later start.
- **WordPress installed with WP-CLI** at the first start, so the site is ready without the browser installation page. Two users are created: an administrator and an author.
- **A healthcheck on MariaDB** and `depends_on: condition: service_healthy`, so WordPress starts only once the database accepts connections.
- **Passwords as Docker secrets**, other settings in `srcs/.env`. Neither is committed to the repository.
- **Self-signed TLS certificate**, generated when the nginx image is built.
- **Restart policy `unless-stopped`**, so containers restart after a crash or a reboot.

### Virtual Machines vs Docker

A virtual machine emulates a complete computer and runs its own operating system kernel. A Docker container shares the host's kernel and isolates only the processes, files and network of one application. Containers therefore start in about a second and their images are much smaller, while a virtual machine provides stronger isolation and can run a different operating system. This project uses both: a virtual machine as the host, and Docker containers inside it for the services.

### Secrets vs Environment Variables

Environment variables are visible to every process in a container and in the output of `docker inspect`. They are suitable for configuration that is not confidential. Docker secrets are files mounted at `/run/secrets/<name>`, only in the containers that declare them. In this project, `srcs/.env` holds non-confidential settings (domain name, database name, user names), and the four passwords are Docker secrets read from the `secrets/` directory.

### Docker Network vs Host Network

With the host network, a container uses the host's network stack directly: every port it opens is open on the host and there is no isolation between containers. A user-defined Docker bridge network gives the containers a private network in which they reach each other by service name (`mariadb`, `wordpress`). Only ports explicitly published, here 443 on nginx, are reachable from outside. This project uses one bridge network named `inception`.

### Docker Volumes vs Bind Mounts

A bind mount maps an existing host directory directly into a container and is not managed by Docker. A named volume is created and managed by Docker, which lists, inspects and removes it with `docker volume` commands. This project uses two named volumes, `mariadb_data` and `wordpress_data`. They use the `local` driver with options that store their data in `/home/kmummadi/data`, as the subject requires, while remaining named volumes.

## Instructions

### Prerequisites

- A Linux virtual machine with Docker Engine, the Docker Compose plugin, `make` and `sudo`.
- The domain pointing to the machine. Add this line to `/etc/hosts`:

```
127.0.0.1 kmummadi.42.fr
```

### Configuration

```sh
cp srcs/.env.example srcs/.env
cp -r secrets.example secrets
```

Then replace the placeholder in each of the four files in `secrets/` with a password, and review the values in `srcs/.env`. The WordPress administrator's name must not contain "admin" or "administrator".

### Build and run

```sh
make            # create the data directories, build the images, start the containers
make down       # stop and remove the containers
make clean      # also remove the images (data is kept)
make fclean     # also remove the volumes and all data in /home/kmummadi/data
make re         # fclean, then make
```

Once the containers are running, open `https://kmummadi.42.fr` in the virtual machine's browser and accept the self-signed certificate warning. The administration panel is at `https://kmummadi.42.fr/wp-admin`.

See [USER_DOC.md](USER_DOC.md) for day-to-day use and [DEV_DOC.md](DEV_DOC.md) for developer details.

## Resources

### Documentation

- Dockerfile reference: https://docs.docker.com/reference/dockerfile/
- Docker Compose: https://docs.docker.com/reference/cli/docker/compose/
- Compose startup order and healthchecks: https://docs.docker.com/compose/how-tos/startup-order/
- Compose secrets: https://docs.docker.com/compose/how-tos/use-secrets/
- Compose volumes: https://docs.docker.com/reference/compose-file/volumes/
- Docker bridge networks: https://docs.docker.com/engine/network/drivers/bridge/
- MariaDB `mariadb-install-db`: https://mariadb.com/docs/server/clients-and-utilities/deployment-tools/mariadb-install-db
- MariaDB server system variables: https://mariadb.com/docs/server/server-management/variables-and-modes/server-system-variables
- WP-CLI installation: https://make.wordpress.org/cli/handbook/guides/installing/
- WP-CLI commands: https://developer.wordpress.org/cli/commands/
- PHP-FPM configuration: https://www.php.net/manual/en/install.fpm.configuration.php
- NGINX HTTPS configuration: https://nginx.org/en/docs/http/configuring_https_servers.html
- NGINX FastCGI module: https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html
- OpenSSL `req`: https://docs.openssl.org/3.0/man1/openssl-req/
- Debian releases: https://www.debian.org/releases/

### Use of AI

AI was used for:

- Generation of .md files and boilerplate code
- Learning the concepts, understanding the documentations and other important aspects of the project
- Debugging and testing
