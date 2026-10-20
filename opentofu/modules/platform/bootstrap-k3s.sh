#!/usr/bin/env bash
set -euo pipefail
source /etc/openstack-talk/bootstrap.env
install -d -m 0755 /run/sshd
sshd -t
systemctl restart ssh.service
# Nova becomes ACTIVE before Cinder attachment completes. Wait for the exact
# recorded disk, then use the same signature/size checks as manual provisioning.
for attempt in $(seq 1 120); do
  if lsblk -dnpo SERIAL | awk -v full="$DATA_VOLUME_ID" -v short="${DATA_VOLUME_ID:0:20}" '$1 == full || $1 == short {found=1} END {exit !found}'; then
    break
  fi
  sleep 5
done
bash /etc/openstack-talk/mount-data-volume.sh "$DATA_VOLUME_ID" "$DATA_VOLUME_SIZE"
install -d -m 0700 /mnt/platform-data/k3s
install -d -m 0755 /mnt/platform-data/workloads /etc/rancher/k3s
if [[ ! -x /usr/local/bin/k3s ]] || ! /usr/local/bin/k3s --version | head -1 | grep -Fq "$K3S_VERSION"; then
  curl --fail --location --retry 3 --output /usr/local/bin/k3s.new "$K3S_BINARY_URL"
  printf '%s  %s\n' "$K3S_SHA256" /usr/local/bin/k3s.new | sha256sum -c -
  chmod 0755 /usr/local/bin/k3s.new
  mv /usr/local/bin/k3s.new /usr/local/bin/k3s
fi
# The fallback uses the runtime shipped with the pinned k3s release. The image's
# kubeadm/containerd packages remain available for the later CAPI phase.
systemctl disable --now kubelet containerd || true
uuid=$(cloud-init query ds.meta_data.uuid)
[[ "$uuid" =~ ^[a-f0-9-]{36}$ ]]
printf 'kubelet-arg:\n  - cloud-provider=external\n  - provider-id=openstack:///%s\n' "$uuid" >> /etc/rancher/k3s/config.yaml
cat > /etc/systemd/system/k3s.service <<'UNIT'
[Unit]
Description=Lightweight Kubernetes
Wants=network-online.target
After=network-online.target
RequiresMountsFor=/mnt/platform-data
[Service]
Type=notify
ExecStart=/usr/local/bin/k3s server
Restart=always
RestartSec=5s
KillMode=process
Delegate=yes
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now k3s
install -d -m 0755 /var/lib/openstack-talk
printf 'phase 3 Kubernetes started\n' > /var/lib/openstack-talk/infra-ready
