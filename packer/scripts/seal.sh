#!/usr/bin/env bash
set -euo pipefail
# The next boot must discover new metadata, regenerate host keys and machine identity,
# and receive only the new instance's authorized keys. No builder identity is retained.
cloud-init clean --logs --seed --machine-id
rm -f /etc/ssh/ssh_host_*
find /home /root -type f -name authorized_keys -delete
rm -f /root/.bash_history /home/ubuntu/.bash_history
rm -f /var/lib/dbus/machine-id
truncate -s 0 /etc/machine-id
find /var/log -type f -exec truncate -s 0 {} \;
rm -f /tmp/script_*.sh
sync
