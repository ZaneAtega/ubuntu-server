unzip -q /www/source/themes/all-themes.zip -d /tmp/all-themes

for site in /www/wwwroot/*; do
    rsync -av --delete "/tmp/all-themes/$(basename "$site")/wp-content/themes/" "$site/wp-content/themes"
done

rm -rf /tmp/all-themes

cp -a '/www/source/etc letsencrypt live/.' /etc/letsencrypt/live/