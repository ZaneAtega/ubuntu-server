rm -f /www/backups/backups.zip

zip='zip -r /www/backups/backups.zip /www/wwwroot/ -x "*/uploads/*" "*/wp-content/uploads/*" "*/wp-admin/*" "*/wp-includes/*" "*/h-cache/*"'

sql=''
TMP_DIR=$(mktemp -d)

for site in /www/wwwroot/*; do
    if [ -f "$site" ]; then
        zip+=" \"$site\"/*.xml"
        continue
    fi

    if [[ "$site" != *honkaihaven* ]]; then
        zip+=" \"$site/*.xml\""
    fi

    wp_config="$site/wp-config.php"

    user=$(grep -oP "define\s*\(\s*['\"]DB_USER['\"]\s*,\s*['\"]\K[^'\"]+" "$wp_config")
    password=$(grep -oP "define\s*\(\s*['\"]DB_PASSWORD['\"]\s*,\s*['\"]\K[^'\"]+" "$wp_config")

    sql+=" && mysqldump -u $user -p'$password' $user | gzip > $TMP_DIR/$user.sql.gz"
done

eval "$zip$sql"

zip -rj /www/backups/db.zip $TMP_DIR
rm -rf $TMP_DIR