OUTPUT='/www/source/themes/all-themes.zip'
rm -f "$OUTPUT"

TMP_DIR=$(mktemp -d)

for site in /www/wwwroot/*; do
    site_name=$(basename "$site")
    mkdir -p "$TMP_DIR/$site_name/wp-content"
    cp -r "$site/wp-content/themes" "$TMP_DIR/$site_name/wp-content/"
done

cd "$TMP_DIR" || exit 1
zip -r "$OUTPUT" .

rm -rf "$TMP_DIR"

cp -a /etc/letsencrypt/live/. '/www/source/etc letsencrypt live/'