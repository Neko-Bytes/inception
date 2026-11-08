#!/bin/bash
set -e

# Create dir for TLS certificate
mkdir -p /etc/nginx/ssl

# Generate a self-signed certificate
# -subj flag: Sets the subject non-interactively. CN must match our domain
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/nginx.key \
    -out /etc/nginx/ssl/nginx.crt \
    -subj "/C=MO/ST=KH/O=42/OU=42/CN=${DOMAIN_NAME}"

# Write the NGINX config file. Refer the link below
# https://docs.nginx.com/nginx/admin-guide/security-controls/terminating-ssl-http?source=post_page-----fc601c8307bf----------------------
cat <<EOF>> /etc/nginx/nginx.conf
events {}

http {
    include /etc/nginx/mime.types;
        server {
                listen 443 ssl;
                server_name ${DOMAIN_NAME};
                root /var/www/html;
                index index.php index.html;
                ssl_certificate /etc/nginx/ssl/nginx.crt;
                ssl_certificate_key /etc/nginx/ssl/nginx.key;

                # Restrict to strong TLS versions only. This is the mandatory setting.
                ssl_protocols TLSv1.2 TLSv1.3;

                location ~ \.php$ {
                include fastcgi_params;
                # Forward PHP requests to the WordPress container by its service name.
                fastcgi_pass wordpress:9000;
                fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        }
    }
}
EOF
