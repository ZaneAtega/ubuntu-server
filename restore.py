import os
import re

wwwroot = r""

db = {}

for site in os.listdir(wwwroot):
    wp_config = os.path.join(wwwroot, site, "wp-config.php")

    with open(wp_config, encoding="utf-8") as f:
        config = f.read()

    name, user, password = re.findall(
        r"define\s*\(\s*['\"]DB_(?:NAME|USER|PASSWORD)['\"]\s*,\s*['\"]([^'\"]+)['\"]",
        config
    )

    db[name] = (user, password)

with open("restore_sql.sql", 'w', encoding="utf-8", newline="\n") as f:
    for name, (user, password) in db.items():
        f.write(
            f"CREATE DATABASE IF NOT EXISTS {name};\n"
            f"CREATE USER '{user}'@'localhost' IDENTIFIED BY '{password}';\n"
            f"GRANT ALL PRIVILEGES ON {name}.* TO '{user}'@'localhost';\n"
            "\n"
        )

    f.write("FLUSH PRIVILEGES;")

with open("import_db.sh", 'w') as f:
    for name, (user, password) in db.items():
        f.write(
            f"pv /www/backups/db/{name}.sql.gz | gunzip | mysql -u {user} -p'{password}' {name}\n"
        )