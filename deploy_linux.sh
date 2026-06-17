#!/bin/bash

# ==============================================================================
# Vee Landing Page Production Deployment Script (Server-Side)
# ==============================================================================

set -euo pipefail

SITE_DIR="/var/www/vee-landing-page"
NGINX_CONF="/etc/nginx/sites-available/vee-app.co.il.conf"
NGINX_BACKUP="/etc/nginx/sites-available/vee-app.co.il.conf.landing-bak"
LOG_FILE="deploy_output.log"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    local message="$1"
    local level="${2:-INFO}"
    local color="$NC"
    case "$level" in
        "INFO") color="$BLUE" ;;
        "SUCCESS") color="$GREEN" ;;
        "WARN") color="$YELLOW" ;;
        "ERROR") color="$RED" ;;
    esac
    echo -e "${color}[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $message${NC}" | tee -a "$LOG_FILE"
}

log "Starting Vee landing page deployment..." "INFO"

log "Syncing repository to origin/main..."
git fetch origin main
git reset --hard origin/main

log "Publishing static landing assets to $SITE_DIR..."
mkdir -p "$SITE_DIR/landing-assets/assets"
cp index.html "$SITE_DIR/index.html"
cp styles.css "$SITE_DIR/landing-assets/styles.css"
cp script.js "$SITE_DIR/landing-assets/script.js"
cp -r assets/. "$SITE_DIR/landing-assets/assets/"
chown -R www-data:www-data "$SITE_DIR"

if [ -f "$NGINX_CONF" ] && [ ! -f "$NGINX_BACKUP" ]; then
    log "Backing up current Nginx config to $NGINX_BACKUP..."
    cp "$NGINX_CONF" "$NGINX_BACKUP"
fi

log "Writing Nginx config: root landing page, app routes remain proxied to Vee backend..."
cat > "$NGINX_CONF" <<'NGINX'
server {
    server_name vee-app.co.il www.vee-app.co.il;

    # Security Headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    # Gzip Compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    location = / {
        root /var/www/vee-landing-page;
        try_files /index.html =404;
    }

    location /landing-assets/ {
        alias /var/www/vee-landing-page/landing-assets/;
        access_log off;
        expires 30d;
        add_header Cache-Control "public, max-age=2592000";
    }

    location /text-to-pdf {
        proxy_pass http://localhost:3002;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection upgrade;
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /serve-monitor {
        proxy_pass http://localhost:4010;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection upgrade;
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection upgrade;
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    listen 443 ssl; # managed by Certbot
    ssl_certificate /etc/letsencrypt/live/vee-app.co.il/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/vee-app.co.il/privkey.pem; # managed by Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot
}

server {
    if ($host = www.vee-app.co.il) {
        return 301 https://$host$request_uri;
    } # managed by Certbot

    if ($host = vee-app.co.il) {
        return 301 https://$host$request_uri;
    } # managed by Certbot

    listen 80;
    server_name vee-app.co.il www.vee-app.co.il;
    return 404; # managed by Certbot
}
NGINX

log "Testing Nginx config..."
nginx -t

log "Reloading Nginx..."
systemctl reload nginx

log "Verifying landing page response..."
HEALTH_FILE="$(mktemp)"
if curl -fsS https://vee-app.co.il/ -o "$HEALTH_FILE" && grep -q "landing-assets/styles.css" "$HEALTH_FILE"; then
    rm -f "$HEALTH_FILE"
    log "Landing page health check passed." "SUCCESS"
else
    rm -f "$HEALTH_FILE"
    log "Landing page health check failed." "ERROR"
    exit 1
fi

log "Vee landing page deployment complete." "SUCCESS"
