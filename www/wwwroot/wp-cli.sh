for site in /www/wwwroot/*/; do
    echo "=== $site ==="
    sudo -u www-data -- php /www/wwwroot/wp-cli.phar core verify-checksums --path="$site"
done