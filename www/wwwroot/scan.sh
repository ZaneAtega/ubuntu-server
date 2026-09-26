for site in /www/wwwroot/*; do
    echo "=== $site ==="
    sudo -u www-data -- php /www/wwwroot/wp-cli.phar core verify-checksums --path="$site"
    sudo -u www-data -- php /www/wwwroot/wp-cli.phar plugin verify-checksums --all --path="$site"
done

find /www/wwwroot/* \
    -type d \( -name wp-admin -o -name wp-content -o -name wp-includes -o -path '*/.well-known/acme-challenge' \) -prune -o \( \
    -type f \
        ! -name 'readme*.html' ! -name 'sitemap-*.xml' ! -name 'wp-*.php' \
        ! -name '.user.ini' ! -name 'index.php' ! -name 'license.txt' ! -name 'robots.txt' ! -name 'xmlrpc.php' -o \
    -type l \) \
    -printf '%p\n' | sort -u

find /www/wwwroot/*/.well-known/acme-challenge -mindepth 1 -printf '%p\n' 2>/dev/null

find /www/wwwroot/*/wp-config.php |
while read -r file; do
    while IFS= read -r line; do
        [[ -z "$line" ||
           "$line" == '<?php' ||
           "$line" == '/'* ||
           "$line" == ' *'* ||
           "$line" == "\$table_prefix = 'wp_';" ||
           "$line" == "if ( ! defined( 'ABSPATH' ) ) {" ||
           "$line" == '}' ||
           "$line" == "require_once ABSPATH . 'wp-settings.php';"
        ]] && continue

        line="${line//[[:space:]]/}"
        # [[ $(echo "$line" | awk "/^define\('[A-Za-z_][A-Za-z0-9_]*',(true|false|'[^']*')\);$/ { print \"yes\"; exit }") == "yes" ]] && continue
        [[
           "$line" == "define('ABSPATH',__DIR__.'/');" ||
           $(echo "$line" | awk "/^define\('(WP2FA_ENCRYPT_KEY|DB_NAME|DB_USER|DB_PASSWORD|DB_HOST|DB_CHARSET|DB_COLLATE|AUTH_KEY|SECURE_AUTH_KEY|LOGGED_IN_KEY|NONCE_KEY|AUTH_SALT|SECURE_AUTH_SALT|LOGGED_IN_SALT|NONCE_SALT|WP_CACHE_KEY_SALT|FS_METHOD|WP_AUTO_UPDATE_CORE)','[^']*'\);$/ { print \"yes\"; exit }") == "yes" ||
           $(echo "$line" | awk "/^define\('(WP_POST_REVISIONS|WP_DEBUG|WP_DEBUG_DISPLAY|WP_DEBUG_LOG|DISALLOW_FILE_EDIT|DISABLE_WP_CRON|WP_AUTO_UPDATE_CORE|WP_REDIS_PERSISTENT|WP_REDIS_DISABLE_METRICS)',(true|false)\);$/ { print \"yes\"; exit }") == "yes"
        ]] && continue

        echo "$file: $line"
    done < "$file"
done

TMP_THEMES=$(mktemp -d)
unzip -q /www/source/themes/all-themes.zip -d "$TMP_THEMES"

for site in /www/wwwroot/*; do
    name=$(basename "$site")
    content="${site}wp-content"
    uploads="${content}/uploads"

    echo "=== $name ==="

    [[ "$(cat "$site/.user.ini" 2>/dev/null)" == "open_basedir=$site/:/tmp/
session.save_path=${site}/sessions" ]] || echo "BAD: $site/.user.ini"

    find "$content" -mindepth 1 -maxdepth 1 \
        ! -name 'index.php' ! -name 'object-cache.php' ! -name 'debug.log' \
        ! -name 'mu-plugins' ! -name 'upgrade' ! -name 'upgrade-temp-backup' ! -name 'uploads' ! -name 'plugins' ! -name 'themes'

    diff -q "$content/index.php" /www/source/scan/index.php
    diff -q "$content/object-cache.php" /www/source/scan/object-cache.php
    diff -qr "$content/mu-plugins" /www/source/mu-plugins
    diff -qr "$content/themes" "$TMP_THEMES/$name/wp-content/themes"

    find "$content/upgrade" -mindepth 1 2>/dev/null
    find "$content/upgrade-temp-backup" -mindepth 1 2>/dev/null

    # Uploads

    find "$uploads" -mindepth 1 -maxdepth 1 ! -name 'nsl_avatars' ! -name 'wp-rollback' ! -name '2026'

    find "$uploads/nsl_avatars" -type f ! -name '*.jpg' ! -name '*.png' ! -name '*.webp' ! -name '*.gif' 2>/dev/null

    if [ -d "$uploads/wp-rollback" ]; then
        find "$uploads/wp-rollback" -mindepth 1 ! -name '.htaccess' ! -name 'index.php'
        [ "$(cat "$uploads/wp-rollback/.htaccess" 2>/dev/null)" = 'Deny from all' ] || echo "BAD: $uploads/wp-rollback/.htaccess"
        [ "$(cat "$uploads/wp-rollback/index.php" 2>/dev/null)" = '<?php // Silence is golden' ] || echo "BAD: $uploads/wp-rollback/index.php"
    fi

    if [[ "$name" == *honkaihaven* ]]; then
        find "$uploads"/20[0-9][0-9] -type f ! -name '*.webp' ! -name '*.mp4' -o -type l
    else
        find "$uploads"/20[0-9][0-9] -type d -empty -delete 2>/dev/null
        find "$uploads"/20[0-9][0-9] 2>/dev/null 
    fi
done

rm -rf "$TMP_THEMES"