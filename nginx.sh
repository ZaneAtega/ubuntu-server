conf='include /etc/nginx/global/map.conf;

'

# Cloudflare: Full (strict)
# No Cloudflare "Proxied" = ERR_QUIC_PROTOCOL_ERROR

for site in /www/wwwroot/*; do
    [[ -d "$site" ]] || continue

    domain=$(basename "$site")

    conf+="server {
    listen 443 ssl;
    listen [::]:443 ssl;

    ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;

    server_name $domain;

    root $site;

    include /etc/nginx/global/wordpress.conf;
    include /etc/nginx/global/ssl.conf;
    include /etc/nginx/global/h.conf;
}

"
done

printf '%s' "$conf" > /etc/nginx/sites-available/site.conf

rm /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/site.conf /etc/nginx/sites-enabled/
ln -s /etc/nginx/sites-available/s3.conf /etc/nginx/sites-enabled/

systemctl reload nginx

# tail -50 /var/log/nginx/error.log