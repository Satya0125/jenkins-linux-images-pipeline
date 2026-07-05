#!/bin/bash
# cis_harden.sh
# Applies a baseline set of CIS Ubuntu Linux hardening controls.
# Run as root during Packer's shell provisioner step.

set -euo pipefail
echo ">>> Starting CIS hardening..."

# ---------------------------------------------------------------------------
# 1. System updates
# ---------------------------------------------------------------------------
apt-get update -y
apt-get upgrade -y

# ---------------------------------------------------------------------------
# 2. Filesystem / kernel hardening
# ---------------------------------------------------------------------------
# Disable unused filesystems (CIS 1.1.1.x)
cat <<EOF > /etc/modprobe.d/cis-disable-fs.conf
install cramfs /bin/true
install freevxfs /bin/true
install jffs2 /bin/true
install hfs /bin/true
install hfsplus /bin/true
install udf /bin/true
EOF

# Kernel network hardening (CIS 3.x)
cat <<EOF > /etc/sysctl.d/60-cis-hardening.conf
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.tcp_syncookies = 1
kernel.randomize_va_space = 2
EOF
sysctl --system

# ---------------------------------------------------------------------------
# 3. SSH hardening (CIS 5.2.x)
# ---------------------------------------------------------------------------
SSHD_CONFIG=/etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' $SSHD_CONFIG
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' $SSHD_CONFIG
sed -i 's/^#\?X11Forwarding.*/X11Forwarding no/' $SSHD_CONFIG
sed -i 's/^#\?MaxAuthTries.*/MaxAuthTries 4/' $SSHD_CONFIG
grep -q '^Protocol' $SSHD_CONFIG || echo "Protocol 2" >> $SSHD_CONFIG

# ---------------------------------------------------------------------------
# 4. Password policy (CIS 5.4.x)
# ---------------------------------------------------------------------------
apt-get install -y libpam-pwquality
cat <<EOF >> /etc/security/pwquality.conf
minlen = 14
dcredit = -1
ucredit = -1
ocredit = -1
lcredit = -1
EOF

sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   365/' /etc/login.defs
sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS   1/' /etc/login.defs
sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE   7/' /etc/login.defs

# ---------------------------------------------------------------------------
# 5. Auditd (CIS 4.1.x)
# ---------------------------------------------------------------------------
apt-get install -y auditd audispd-plugins
systemctl enable auditd

# ---------------------------------------------------------------------------
# 6. Remove unnecessary packages / disable unused services
# ---------------------------------------------------------------------------
apt-get purge -y telnet rsh-client talk xinetd || true
systemctl disable avahi-daemon 2>/dev/null || true
systemctl disable cups 2>/dev/null || true

# ---------------------------------------------------------------------------
# 7. File permissions on critical files (CIS 6.1.x)
# ---------------------------------------------------------------------------
chmod 644 /etc/passwd
chmod 644 /etc/group
chmod 600 /etc/shadow
chmod 600 /etc/gshadow

echo ">>> CIS hardening complete."
