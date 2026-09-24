unzip /www/backups/backups.zip -d /

TMP_DIR=$(mktemp -d)
unzip /www/backups/wordpress-*.zip -d "$TMP_DIR"

for site in /www/wwwroot/test; do
    cp -r "$TMP_DIR/wordpress/wp-admin" "$site"/
    cp -r "$TMP_DIR/wordpress/wp-includes" "$site"/
done

rm -rf "$TMP_DIR"

bash /www/source/themes/import_themes_and_ssl.sh
bash /www/source/source.sh

chown -R www-data:www-data /www/wwwroot
find /www/wwwroot -type d -exec chmod 755 {} \;
find /www/wwwroot -type f -exec chmod 644 {} \;

unzip /www/backups/db.zip -d /www/backups/db

# CREATE DATABASE, CREATE USER, GRANT, FLUSH PRIVILEGES
# restore.py restore_sql_ready.sql

# mysql -e "SELECT @@GLOBAL.autocommit, @@GLOBAL.unique_checks, @@GLOBAL.foreign_key_checks;"

mysql -e "
SET GLOBAL autocommit = 0;
SET GLOBAL unique_checks = 0;
SET GLOBAL foreign_key_checks = 0;
"

pv /www/backups/db/example.sql.gz | gunzip | mysql -u foo -p bar
# restore.py import_db.sh

mysql -e "
COMMIT;
SET GLOBAL foreign_key_checks = 1;
SET GLOBAL unique_checks = 1;
SET GLOBAL autocommit = 1;
"