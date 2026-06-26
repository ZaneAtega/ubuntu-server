# scp -i "id_ed25519" -r "*.zip" root@:/www/backups

unzip /www/backups/backups.zip -d /www/wwwroot

chown -R www-data:www-data /www/wwwroot
find /www/wwwroot -type d -exec chmod 755 {} \;
find /www/wwwroot -type f -exec chmod 644 {} \;

unzip /www/backups/db.zip -d /www/backups/db

# CREATE DATABASE, CREATE USER, GRANT, FLUSH PRIVILEGES

# mysql -e "SELECT @@GLOBAL.autocommit, @@GLOBAL.unique_checks, @@GLOBAL.foreign_key_checks;"

mysql -e "
SET GLOBAL autocommit = 0;
SET GLOBAL unique_checks = 0;
SET GLOBAL foreign_key_checks = 0;
"

pv /www/backups/db/example.sql.gz | gunzip | mysql -u foo -p bar

mysql -e "
COMMIT;
SET GLOBAL foreign_key_checks = 1;
SET GLOBAL unique_checks = 1;
SET GLOBAL autocommit = 1;
"