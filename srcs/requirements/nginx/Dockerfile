FROM debian:bookworm-slim

# Install NGINX and OpenSSL.
RUN apt-get update && \
    apt-get install -y --no-install-recommends nginx openssl && \
    rm -rf /var/lib/apt/lists/*

# Create a self-signed HTTPS certificate.
RUN mkdir -p /etc/nginx/ssl && \
    openssl req -x509 -nodes -days 365 \
    -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/nginx.key \
    -out /etc/nginx/ssl/nginx.crt \
    -subj "/CN=kmummadi.42.fr" \
    -addext "subjectAltName=DNS:kmummadi.42.fr" && \
    chmod 600 /etc/nginx/ssl/nginx.key

# Add our NGINX configuration.
COPY conf/default.conf /etc/nginx/conf.d/default.conf

# Remove the default website configuration.
RUN rm -f /etc/nginx/sites-enabled/default

EXPOSE 443

# Run NGINX in the foreground.
CMD ["nginx", "-g", "daemon off;"]
