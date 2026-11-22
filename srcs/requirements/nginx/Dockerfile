# nginx image (the only container reachable from outside)
#
# What it does:
#   1. starts from Debian 12 "bookworm" (the penultimate stable Debian)
#   2. installs nginx and openssl
#   3. makes a self-signed TLS certificate for our domain
#   4. adds our config
#   5. runs nginx in the foreground
#
# Sources:
#   Dockerfile reference: https://docs.docker.com/reference/dockerfile/
#   openssl req:          https://docs.openssl.org/3.0/man1/openssl-req/
#   daemon off:           https://nginx.org/en/docs/ngx_core_module.html

FROM debian:bookworm

RUN apt-get update && apt-get install -y nginx openssl && rm -rf /var/lib/apt/lists/*

# self-signed certificate, valid 1 year
#   -x509 = make a certificate (not a request), -nodes = no password on the key
#   -subj = the certificate's name (CN = our domain), so openssl doesn't ask questions
RUN mkdir -p /etc/nginx/ssl && \
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/nginx/ssl/inception.key \
        -out /etc/nginx/ssl/inception.crt \
        -subj "/CN=kmummadi.42.fr"

# remove Debian's default site (it listens on port 80, we don't want that)
RUN rm -f /etc/nginx/sites-enabled/default

# Debian's nginx loads every .conf file in conf.d/
COPY conf/default.conf /etc/nginx/conf.d/default.conf

# daemon off = stay in the foreground, so nginx is PID 1 and the container keeps running
CMD ["nginx", "-g", "daemon off;"]
