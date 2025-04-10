
#!/bin/bash
#
# Setup for Control Plane (Master 1) server in HA mode

set -euxo pipefail

# Configuration
PUBLIC_IP_ACCESS="false"
CONTROL_PLANE_ENDPOINT="192.168.112.250"  # VIP via HAProxy
POD_CIDR="192.168.112.0/16"
NODENAME=$(hostname -s)

# Pull required images
sudo kubeadm config images pull

# Initialize kubeadm
if [[ "$PUBLIC_IP_ACCESS" == "false" ]]; then
    
    MASTER_IP=$(ip addr show ens33 | awk '/inet / {print $2}' | cut -d/ -f1)

    sudo kubeadm init \
      --control-plane-endpoint="${CONTROL_PLANE_ENDPOINT}:6443" \
      --apiserver-advertise-address="$MASTER_IP" \
      --apiserver-cert-extra-sans="$CONTROL_PLANE_ENDPOINT" \
      --pod-network-cidr="$POD_CIDR" \
      --node-name "$NODENAME" \
      --upload-certs \
      --ignore-preflight-errors Swap

else
    MASTER_PUBLIC_IP=$(curl -s ifconfig.me)
    sudo kubeadm init \
      --control-plane-endpoint="$MASTER_PUBLIC_IP:6443" \
      --apiserver-cert-extra-sans="$MASTER_PUBLIC_IP" \
      --pod-network-cidr="$POD_CIDR" \
      --node-name "$NODENAME" \
      --upload-certs \
      --ignore-preflight-errors Swap
fi

# Configure kubeconfig
mkdir -p "$HOME"/.kube
sudo cp -i /etc/kubernetes/admin.conf "$HOME"/.kube/config
sudo chown "$(id -u)":"$(id -g)" "$HOME"/.kube/config

# Install Calico Network Plugin
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# Print join command for Master 2
CERT_KEY=$(kubeadm init phase upload-certs --upload-certs | tail -1)
JOIN_CMD=$(kubeadm token create --print-join-command)

echo
echo "👉 Commande pour joindre le second master (control plane) :"
echo
echo "$JOIN_CMD --control-plane --certificate-key $CERT_KEY"
echo
