for site in /www/wwwroot/*; do
    for plugin in /www/source/plugins/*; do
        rsync -av --delete "$plugin/" "$site/wp-content/plugins/$(basename "$plugin")/"
    done

    mu="$site/wp-content/mu-plugins"
    rsync -av --delete /www/source/mu-plugins/ "$mu/"

    cp -r /www/source/root/. "$site"/
done

systemctl reload php8.3-fpm