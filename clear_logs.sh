truncate -s 0 /var/log/*.log
truncate -s 0 /var/log/syslog
journalctl --vacuum-time=1s