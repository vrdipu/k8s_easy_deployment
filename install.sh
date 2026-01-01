set -euxo pipefail

# -----------------------------
# 0) Variables (latest stable lines)
# -----------------------------
K8S_MINOR="v1.35"          # supported/latest minor line
CONTAINERD_VER="2.2.0"
RUNC_VER="1.4.0"

# -----------------------------
# 1) Disable swap (runtime + permanent)
# -----------------------------
swapoff -a
# Comment any swap entries safely (covers swapfile and swap partitions)
sed -ri 's/^(\s*[^#].*\s+swap\s+sw\s+.*)$/# \1/g' /etc/fstab

# -----------------------------
# 2) Kernel modules + sysctl needed for Kubernetes networking
# -----------------------------
cat <<EOF >/etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

cat <<EOF >/etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system

# -----------------------------
# 3) Base deps
# -----------------------------
apt-get update
apt-get install -y ca-certificates curl wget gpg apt-transport-https

# -----------------------------
# 4) Install containerd (latest stable) from official tarball
# -----------------------------
wget -q "https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VER}/containerd-${CONTAINERD_VER}-linux-amd64.tar.gz"
tar Cxzvf /usr/local "containerd-${CONTAINERD_VER}-linux-amd64.tar.gz"

# Install containerd systemd service file
wget -qO /usr/lib/systemd/system/containerd.service \
  https://raw.githubusercontent.com/containerd/containerd/main/containerd.service

systemctl daemon-reload
systemctl enable --now containerd

# -----------------------------
# 5) Install runc (latest stable)
# -----------------------------
wget -qO runc.amd64 "https://github.com/opencontainers/runc/releases/download/v${RUNC_VER}/runc.amd64"
install -m 755 runc.amd64 /usr/local/sbin/runc

# -----------------------------
# 6) Configure containerd for Kubernetes (SystemdCgroup = true)
# -----------------------------
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml >/dev/null
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd

# -----------------------------
# 7) Install Kubernetes (kubelet/kubeadm/kubectl) from pkgs.k8s.io (latest stable minor line)
# -----------------------------
mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL "https://pkgs.k8s.io/core:/stable:/${K8S_MINOR}/deb/Release.key" \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_MINOR}/deb/ /" \
  | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y kubelet kubeadm kubectl
systemctl enable --now kubelet

# Optional: prevent accidental drift (recommended for stable labs)
apt-mark hold kubelet kubeadm kubectl

# -----------------------------
# 8) Initialize cluster (Flannel CIDR) using containerd CRI socket
# -----------------------------
kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --cri-socket=unix:///var/run/containerd/containerd.sock

# -----------------------------
# 9) Configure kubectl for your user
# -----------------------------
export KUBECONFIG=/etc/kubernetes/admin.conf
mkdir -p "$HOME/.kube"
cp -i /etc/kubernetes/admin.conf "$HOME/.kube/config"
chown "$(id -u):$(id -g)" "$HOME/.kube/config"

# -----------------------------
# 10) Install Flannel CNI
# -----------------------------
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# -----------------------------
# 11) Allow scheduling on control plane (single-node lab)
# -----------------------------
kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true
kubectl get nodes -o wide
