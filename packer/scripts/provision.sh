#!/usr/bin/env bash
set -euo pipefail
cloud-init status --wait
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -y
apt-get install -y ca-certificates curl gpg cloud-init conntrack socat ebtables ethtool unattended-upgrades
install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
printf 'deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu noble stable\n' > /etc/apt/sources.list.d/containerd.list
minor=${KUBERNETES_VERSION%.*}
curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${minor}/deb/Release.key" | gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes.gpg
printf 'deb [signed-by=/etc/apt/keyrings/kubernetes.gpg] https://pkgs.k8s.io/core:/stable:/v%s/deb/ /\n' "$minor" > /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y "containerd.io=$CONTAINERD_PACKAGE_VERSION" "kubeadm=$KUBERNETES_PACKAGE_VERSION" "kubelet=$KUBERNETES_PACKAGE_VERSION" "kubectl=$KUBERNETES_PACKAGE_VERSION"
apt-mark hold containerd.io kubeadm kubelet kubectl
install -d -m 0755 /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
cat > /etc/modules-load.d/kubernetes.conf <<'MODULES'
overlay
br_netfilter
MODULES
modprobe overlay
modprobe br_netfilter
cat > /etc/sysctl.d/90-kubernetes.conf <<'SYSCTL'
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
SYSCTL
sysctl --system
swapoff -a
sed -i '/^[^#].*[[:space:]]swap[[:space:]]/s/^/#/' /etc/fstab
systemctl enable --now containerd
# kubelet is intentionally stopped until kubeadm/CAPI supplies its bootstrap config.
systemctl disable --now kubelet || true
[[ $(kubeadm version -o short) == "v$KUBERNETES_VERSION" ]]
[[ $(kubelet --version) == "Kubernetes v$KUBERNETES_VERSION" ]]
kubectl version --client -o json | python3 -c 'import json,os,sys; assert json.load(sys.stdin)["clientVersion"]["gitVersion"] == "v" + os.environ["KUBERNETES_VERSION"]'
[[ $(dpkg-query -W -f='${Version}' containerd.io) == "$CONTAINERD_PACKAGE_VERSION" ]]
[[ $(ctr plugins ls | awk '$1 == "io.containerd.cri.v1" && $2 == "runtime" {print $NF}') == ok ]]
install -d -m 0755 /etc/openstack-talk
printf '{"kubernetes_version":"%s","containerd_package_version":"%s"}\n' "$KUBERNETES_VERSION" "$CONTAINERD_PACKAGE_VERSION" > /etc/openstack-talk/image.json
cat > /etc/ssh/sshd_config.d/00-platform.conf <<'SSH'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
SSH
install -d -m 0755 /run/sshd
sshd -t
printf 'APT::Periodic::Update-Package-Lists "1";\nAPT::Periodic::Unattended-Upgrade "1";\n' > /etc/apt/apt.conf.d/20auto-upgrades
apt-get clean
