# minimal debian image
FROM debian:bookworm-slim

# Install NGINX and OpenSSL. And then clean the cache
RUN apt-get update && \
    apt-get install -y --no-install-recommends nginx openssl && \
    rm -rf /var/lib/apt/lists/*

# Copy the script into the image
COPY ./tools/setup.sh /setup.sh

# Make it executable and run it
RUN chmod +x /setup.sh && /setup.sh

# Run NGINX in the foreground as the main process
# The official NGINX documentation advises using daemon off; to keep NGINX in the foreground so Docker can properly track the main process. Without it, the container would exit immediately.
ENTRYPOINT ["nginx", "-g", "daemon off;"]
