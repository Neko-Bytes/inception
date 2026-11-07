FROM debian:bookworm-slim

# Install NGINX and OpenSSL. And then clean the cache
RUN apt-get update && \
    apt-get install -y --no-install-recommends nginx openssl && \
    rm -rf /var/lib/apt/lists/*


