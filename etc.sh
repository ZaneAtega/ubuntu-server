# Limits

match=$(grep -E '^(fs\.file-max|fs\.nr_open)' /etc/sysctl.conf)

if read -r -p "$match [Y/n] " answer && [[ "${answer,,}" == 'y' ]]; then
    tee -a /etc/sysctl.conf > /dev/null <<'EOF'
fs.file-max = 2097152
fs.nr_open = 2097152
EOF
fi

match=$(grep -E '^\* (soft|hard) nofile' /etc/security/limits.conf)

if read -r -p "$match [Y/n] " answer && [[ "${answer,,}" == 'y' ]]; then
    tee -a /etc/security/limits.conf > /dev/null <<'EOF'
* soft nofile 65535
* hard nofile 65535
EOF
fi

match=$(grep -H 'pam_limits.so' /etc/pam.d/common-session /etc/pam.d/common-session-noninteractive)

if read -r -p "$match [Y/n] " answer && [[ "${answer,,}" == 'y' ]]; then
    tee -a /etc/pam.d/common-session /etc/pam.d/common-session-noninteractive > /dev/null <<'EOF'
session required pam_limits.so
EOF
fi

# PHP

php_ini='/etc/php/8.3/fpm/php.ini'

match=$(grep -n '^;cgi\.fix_pathinfo' "$php_ini")

if read -r -p "$match [Y/n] " answer && [[ "${answer,,}" == 'y' ]]; then
    sed -i "${match%%:*}a cgi.fix_pathinfo = 0" "$php_ini"
fi

declare -A php=(
    [post_max_size]=
    [memory_limit]=
    [max_execution_time]=
    [upload_max_filesize]=
    [max_file_uploads]=1
)

for directive in "${!php[@]}"; do
    value="${php[$directive]}"

    match=$(grep -n "^$directive" "$php_ini")

    if [[ -z "$match" ]]; then
        echo "$directive not found"
        continue
    fi

    if read -r -p "$match [Y/n] " answer && [[ "${answer,,}" == 'y' ]]; then
        sed -i "${match%%:*}c $directive = $value" "$php_ini"
    fi
done

declare -A opcache=(
    [memory_consumption]=128 # var_dump(opcache_get_status(false)['memory_usage']);
    [interned_strings_buffer]=16 # var_dump(opcache_get_status(false)['interned_strings_usage']);
    [max_accelerated_files]=50000 # find /www/wwwroot/ -type f -name '*.php' | wc -l
    [validate_timestamps]=0
    [enable_file_override]=1
)

for directive in "${!opcache[@]}"; do
    value="${opcache[$directive]}"

    match=$(grep -n "^;opcache\.$directive" "$php_ini")

    if [[ -z "$match" ]]; then
        echo ";opcache.$directive not found"
        continue
    fi

    if read -r -p "$match [Y/n] " answer && [[ "${answer,,}" == 'y' ]]; then
        sed -i "${match%%:*}a opcache.$directive = $value" "$php_ini"
    fi
done

www_conf='/etc/php/8.3/fpm/pool.d/www.conf'

# See memory usage per worker:
# ps -eo pid,rss,cmd | grep php-fpm
# PHP RAM / ^ = pm.max_children
# memory_limit * pm.max_children = max RAM usage

pm=

match=$(grep -n "^pm =" "$www_conf")

if read -r -p "$match [Y/n] " answer && [[ "${answer,,}" == 'y' ]]; then
    sed -i "${match%%:*}c pm = $pm" "$www_conf"
fi

declare -A fpm=(
    [max_children]=
    [start_servers]= # How many PHP workers start immediately when PHP-FPM launches
    [min_spare_servers]= # Minimum idle workers PHP-FPM tries to keep ready
    [max_spare_servers]= # Maximum idle workers allowed
)

# pm.status_path = /status
# pm.status_listen = 127.0.0.1:9001

for directive in "${!fpm[@]}"; do
    value="${fpm[$directive]}"

    match=$(grep -n "^pm\.$directive" "$www_conf")

    if [[ -z "$match" ]]; then
        echo "pm.$directive not found"
        continue
    fi

    if read -r -p "$match [Y/n] " answer && [[ "${answer,,}" == 'y' ]]; then
        sed -i "${match%%:*}c pm.$directive = $value" "$www_conf"
    fi
done

cat > /etc/php/8.3/mods-available/xdebug.ini <<'EOF'
zend_extension = xdebug.so
xdebug.mode = profile
xdebug.start_with_request = trigger
xdebug.output_dir = /tmp/xdebug
EOF

# Redis

match=$(grep -En '^[[:space:]]*(save|maxmemory)' /etc/redis/redis.conf)

if read -r -p "$match [Y/n] " answer && [[ "${answer,,}" == 'y' ]]; then
    tee -a /etc/redis/redis.conf > /dev/null <<'EOF'
save ""

# redis-cli INFO stats | grep -E 'keyspace_hits|keyspace_misses|evicted_keys'
maxmemory 1gb

maxmemory-policy allkeys-lru
EOF
fi

# MySQL

