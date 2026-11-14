# Use Debian 12 Slim, as required by the subject.
FROM debian:bookworm-slim

# Install MariaDB and remove temporary package files.
RUN apt-get update && \
    apt-get install -y --no-install-recommends mariadb-server && \
    rm -rf /var/lib/apt/lists/*

# Copy our settings and first-time setup script.
COPY conf/server.cnf /etc/mysql/mariadb.conf.d/60-inception.cnf
COPY tools/setup.sh /usr/local/bin/setup.sh

RUN chmod +x /usr/local/bin/setup.sh

# Start MariaDB using our setup script.
ENTRYPOINT ["/usr/local/bin/setup.sh"]
