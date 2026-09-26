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

# Redis

match=$(grep -E '^[[:space:]]*(save|maxmemory)' /etc/redis/redis.conf)

if read -r -p "$match [Y/n] " answer && [[ "${answer,,}" == 'y' ]]; then
    tee -a /etc/redis/redis.conf > /dev/null <<'EOF'
save ""

# redis-cli INFO stats | grep -E 'keyspace_hits|keyspace_misses|evicted_keys'
maxmemory 512mb

maxmemory-policy allkeys-lru
EOF
fi

# NGINX

: <<'EOF'
worker_processes auto; # one worker per CPU core
worker_rlimit_nofile 65535;

events {
	worker_connections 65535;
	# ulimit -n
	use epoll;
}

http {
	sendfile on; # Lets nginx send files directly from disk -> network
	tcp_nopush on; # Bundles HTTP response headers + file chunks into efficient packet sizes before sending
	tcp_nodelay on; # Disables Nagle's algorithm -> sends small packets immediately

	log_format custom_combined '$remote_addr - $remote_user [$time_local] '
	                           '"$request" $status $request_length $upstream_header_time $body_bytes_sent '
	                           '"$http_referer" "$http_user_agent"';

	access_log /var/log/nginx/access.log custom_combined;

	gzip on;
	gzip_comp_level 4; # 9 = max compression, heavy CPU
}
EOF

nginx_conf='/etc/nginx/nginx.conf'

match=$(grep -E '^worker_processes|^worker_rlimit_nofile' "$nginx_conf")

if read -r -p "$match [Y/n] " answer && [[ "${answer,,}" == 'y' ]]; then
    sed -i "2a worker_rlimit_nofile 65535;" "$nginx_conf"
fi

match=$(grep -n '^[[:space:]]*worker_connections' "$nginx_conf")
epoll=$(grep '^[[:space:]]*use[[:space:]]\+epoll' "$nginx_conf")

if read -r -p "$match $epoll [Y/n] " answer && [[ "${answer,,}" == 'y' ]]; then
    line=${match%%:*}
    sed -i "${line}c worker_connections 65535;" "$nginx_conf"
    sed -i "${line}a use epoll;" "$nginx_conf"
fi

grep -E '^[[:space:]]*(sendfile|tcp_nopush|tcp_nodelay|gzip)[[:space:]]' "$nginx_conf"

if read -r -p "[Y/n] " answer && [[ "${answer,,}" == 'y' ]]; then
    sed -i '/^[[:space:]]*tcp_nopush /a tcp_nodelay on;' "$nginx_conf"
fi

match=$(grep -n '^[[:space:]]*access_log' "$nginx_conf")
line=${match%%:*}

if read -r -p "$match [Y/n] " answer && [[ "${answer,,}" == 'y' ]]; then
    sed -i "${line}s/;/ custom_combined;/" "$nginx_conf"
fi

if read -r -p "$(grep -E '^[[:space:]]*log_format' "$nginx_conf") [Y/n] " answer && [[ "${answer,,}" == 'y' ]]; then
    log_options=$(cat <<'EOF'
log_format custom_combined '$remote_addr - $remote_user [$time_local] '
                           '"$request" $status $request_length $upstream_header_time $body_bytes_sent '
                           '"$http_referer" "$http_user_agent"';
EOF
)

    sed -i "${line}i ${log_options//$'\n'/\\$'\n'}" "$nginx_conf"
fi

match=$(grep -n '^[[:space:]]*# gzip_comp_level' "$nginx_conf")

if read -r -p "$match [Y/n] " answer && [[ "${answer,,}" == 'y' ]]; then
    sed -i "${match%%:*}a gzip_comp_level 4;" "$nginx_conf"
fi

rm /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/site.conf /etc/nginx/sites-enabled/
ln -s /etc/nginx/sites-available/s3.conf /etc/nginx/sites-enabled/

# MySQL

mariadb_cnf='/etc/mysql/mariadb.conf.d/50-server.cnf'

declare -A mariadb=(
    [key_buffer_size]=0M
    [query_cache_size]=0M

    # Larger in-memory temp tables = fewer disk writes = faster queries on large datasets
    # SHOW GLOBAL STATUS WHERE Variable_name IN ('Created_tmp_disk_tables', 'Created_tmp_tables');
    [tmp_table_size]=32M
    [max_heap_table_size]=32M

    # https://mariadb.com/docs/server/server-management/variables-and-modes/server-system-variables
    [sort_buffer_size]=2048K # SHOW GLOBAL STATUS WHERE Variable_name = 'Sort_merge_passes';
    [join_buffer_size]=256K # SHOW GLOBAL STATUS WHERE Variable_name = 'Select_full_join';
    [read_buffer_size]=128K # SHOW GLOBAL STATUS WHERE Variable_name IN ('Handler_read_next', 'Handler_read_rnd_next');
    [read_rnd_buffer_size]=256K # SHOW GLOBAL STATUS WHERE Variable_name = 'Handler_read_rnd';

    [max_allowed_packet]=64M

    [thread_stack]=256K # journalctl -u mariadb --no-pager | grep 'stack overrun'
    [thread_cache_size]= # SHOW GLOBAL STATUS WHERE Variable_name IN ('Threads_created', 'Connections');
    [max_connections]= # SHOW GLOBAL STATUS WHERE Variable_name = 'Max_used_connections';

    [table_open_cache]=1024 # SHOW GLOBAL STATUS LIKE 'Open%tables';

    [innodb_ft_min_token_size]=2
    [ft_min_word_len]=2

    # SHOW GLOBAL STATUS WHERE Variable_name IN ('Innodb_buffer_pool_read_requests', 'Innodb_buffer_pool_reads', 'Innodb_buffer_pool_wait_free');
    # (1 - Innodb_buffer_pool_reads / Innodb_buffer_pool_read_requests) * 100
    # SHOW GLOBAL STATUS WHERE Variable_name IN ('Innodb_buffer_pool_pages_total', 'Innodb_buffer_pool_pages_data');
    [innodb_buffer_pool_size]= # / 0.016 > Innodb_buffer_pool_pages_data
    [innodb_log_buffer_size]=32M # SHOW GLOBAL STATUS WHERE Variable_name = 'Innodb_log_waits';

    [innodb_flush_method]=O_DIRECT # InnoDB bypasses the OS filesystem cache and writes directly to disk
    # Avoids double buffering (InnoDB cache + OS cache)

    [innodb_flush_neighbors]=0
    # When a page in memory has been modified but not yet written back to disk,
    # "If I'm writing page X, maybe pages x-1 and x+1 will be needed soon" = write them together
    # Historical HDD optimization

    [innodb_file_per_table]=1 # Easier to reclaim disk space when dropping a table
    # 0: All tables share the same ibdata1
)

match=$(grep -E "$(IFS='|'; echo "${!mariadb[*]}")" "$mariadb_cnf")

if read -r -p "$match [Y/n] " answer && [[ "${answer,,}" == 'y' ]]; then
    options=''

    for option in "${!mariadb[@]}"; do
        options+="$option = ${mariadb[$option]}"$'\n'
    done

    sed -i "$(grep -n '^\[mysqld\]' "$mariadb_cnf" | cut -d: -f1)a ${options//$'\n'/\\$'\n'}" "$mariadb_cnf"
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

# /etc/php/8.3/cli/php.ini