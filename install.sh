apt update && apt full-upgrade -y

apt install sysbench fio stress-ng -y
# benchmark.sh

# apt list --installed | grep apache
systemctl stop apache2
systemctl disable apache2
apt purge apache2 apache2-bin apache2-data apache2-utils libapache2-mod-php8.3 libapache2-mod-php -y

apt install nginx -y

apt install mariadb-server mariadb-client -y
mysql_secure_installation
# Switch to unix_socket authentication Y
# Change the root password? n
# Y

apt install php8.3-fpm php8.3-redis redis-server -y

apt install phpmyadmin -y
# <Ok>
# <Yes> <Ok>

apt install certbot python3-certbot-nginx -y
# certbot --nginx -d example.com

curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
apt install nodejs -y

apt install pv zip rsync -y