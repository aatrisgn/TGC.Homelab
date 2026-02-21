Reference: https://medium.com/@ferdinandklr/creating-a-production-ready-self-hosted-kubernetes-cluster-from-scratch-on-a-vps-ipv6-compatible-660aa5018feb

sudo apt install avahi-daemon
sudo systemctl start avahi-daemon
sudo systemctl enable avahi-daemon
sudo apt update
sudo apt upgrade

sudo cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# sysctl params required by setup, params persist across reboots
sudo cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
# net.ipv6.conf.all.forwarding        = 1 <--Add this line if we care about IPV6>


# Apply sysctl params without reboot
sudo sysctl --system

sudo swapoff -a

# Add Docker's official GPG key:
sudo apt update
sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update

sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# check whether CRI is disabled
cat /etc/containerd/config.toml

sudo bash -c 'containerd config default > /etc/containerd/config.toml'

sudo nano /etc/containerd/config.toml --> Change SystemdCgroup = false to SystemdCgroup = true

sudo apt-get install -y apt-transport-https ca-certificates curl gpg

sudo curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

sudo echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl