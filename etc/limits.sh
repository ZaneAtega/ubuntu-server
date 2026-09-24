grep -E '^(fs\.file-max|fs\.nr_open)' /etc/sysctl.conf
tee -a /etc/sysctl.conf > /dev/null <<'EOF'
fs.file-max = 2097152
fs.n

grep -E '^\* (soft|hard) nofile' /etc/security/limits.conf
sudo tee -a /etc/security/limits.conf > /dev/null <<'EOF'
* soft nofile 65535
* hard nofile 65535
EOF

r_open = 2097152
EOF
grep -H 'pam_limits.so' /etc/pam.d/common-session /etc/pam.d/common-session-noninteractive
sudo tee -a /etc/pam.d/common-session /etc/pam.d/common-session-noninteractive > /dev/null <<'EOF'
session required pam_limits.so
EOF