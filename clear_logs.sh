find /var/log -type f -exec truncate -s 0 {} +
journalctl --vacuum-time=1s