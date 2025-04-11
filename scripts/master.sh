#!/bin/bash
#
# Initialisation du premier master (master1)

set -euxo pipefail

PUBLIC_IP_ACCESS="false"  # true si tu exposes l'API sur l'IP publique
NODENAME=$(hostname -s)
POD_CIDR="192.168.0.0/16"
CONTROL_PLANE_ENDPOINT="192.168.112.250:6443"  # IP/nom DNS du load balancer (obligatoire pour HA)

# Désactiver le swap
sudo swapoff -a

# Récupération de l'adresse IP
if [[ "$PUBLIC_IP_ACCESS" == "true" ]]; then
    MASTER_IP=$(curl -s ifconfig.me)
else
    MASTER_IP=$(ip -o -4 addr list | grep -v '127.0.0.1' | awk '{print $4}' | cut -d/ -f1 | head -n1)
fi

# Pull des images nécessaires
sudo kubeadm config images pull

# Initialisation du master
sudo kubeadm init \
    --control-plane-endpoint="$CONTROL_PLANE_ENDPOINT" \
    --apiserver-advertise-address="$MASTER_IP" \
    --apiserver-cert-extra-sans="$MASTER_IP" \
    --upload-certs \
    --pod-network-cidr="$POD_CIDR" \
    --node-name "$NODENAME" \
    --ignore-preflight-errors Swap

# Configuration de kubectl
mkdir -p "$HOME/.kube"
sudo cp -i /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u)":"$(id -g)" "$HOME/.kube/config"

# Installer Calico
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# Afficher les commandes kubeadm join (pour master2)
echo "======= Commande kubeadm join pour les autres masters ======="
kubeadm token create --print-join-command --ttl 1h
CERT_KEY=$(kubeadm init phase upload-certs --upload-certs | tail -1)
echo "→ Certificate key à utiliser : $CERT_KEY"
