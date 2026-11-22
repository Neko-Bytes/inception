# MariaDB image
#
# What it does:
#   1. starts from Debian 12 "bookworm" (the penultimate stable Debian,
#      13 "trixie" is the current one: https://www.debian.org/releases/)
#   2. installs the MariaDB server
#   3. adds our config file and our start script
#
# Dockerfile reference: https://docs.docker.com/reference/dockerfile/

FROM debian:bookworm

# install MariaDB, then delete apt's download cache to keep the image small
RUN apt-get update && apt-get install -y mariadb-server && rm -rf /var/lib/apt/lists/*

# Debian reads every .cnf file in this folder; "60" makes ours load after its default "50-server.cnf"
COPY conf/server.cnf /etc/mysql/mariadb.conf.d/60-inception.cnf

COPY tools/setup.sh /setup.sh
RUN chmod +x /setup.sh

# the container runs our script when it starts
ENTRYPOINT ["/setup.sh"]
