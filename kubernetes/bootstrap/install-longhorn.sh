#!/usr/bin/env bash
# Install Longhorn CSI with dedicated disk on workers.
# Run from your local machine with KUBECONFIG set.
set -euo pipefail

WORKER_1="192.168.1.202"
WORKER_2="192.168.1.203"
SSH_USER="ubuntu"
LONGHORN_VERSION="1.8.1"   # latest stable — update if needed
LONGHORN_DISK="/dev/sdb"
LONGHORN_PATH="/var/lib/longhorn"

export KUBECONFIG="$(dirname "${BASH_SOURCE[0]}")/kubeconfig"

echo "==> Preparing dedicated Longhorn disk on workers..."
for host in "$WORKER_1" "$WORKER_2"; do
  echo "    Formatting ${LONGHORN_DISK} on ${host}..."
  ssh -o StrictHostKeyChecking=no "${SSH_USER}@${host}" bash <<EOF
set -euo pipefail
# Wipe any existing signatures (LVM, partition table) then format
sudo wipefs -a ${LONGHORN_DISK}
sudo mkfs.ext4 -F ${LONGHORN_DISK}
# Mount permanently
sudo mkdir -p ${LONGHORN_PATH}
if ! grep -q "${LONGHORN_DISK}" /etc/fstab; then
  echo "${LONGHORN_DISK} ${LONGHORN_PATH} ext4 defaults 0 0" | sudo tee -a /etc/fstab
fi
sudo mount -a
echo "    Disk ready on ${host}: \$(df -h ${LONGHORN_PATH} | tail -1)"
EOF
done

echo "==> Installing Longhorn prerequisites on all nodes..."
for host in "$WORKER_1" "$WORKER_2" "192.168.1.209"; do
  ssh -o StrictHostKeyChecking=no "${SSH_USER}@${host}" \
    "sudo apt-get install -y -qq open-iscsi nfs-common && sudo systemctl enable --now iscsid" &
done
wait

echo "==> Adding Longhorn Helm repo..."
helm repo add longhorn https://charts.longhorn.io
helm repo update

echo "==> Installing Longhorn ${LONGHORN_VERSION}..."
kubectl create namespace longhorn-system --dry-run=client -o yaml | kubectl apply -f -

helm install longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --version "${LONGHORN_VERSION}" \
  --set defaultSettings.defaultDataPath="${LONGHORN_PATH}" \
  --set defaultSettings.defaultReplicaCount=2 \
  --set defaultSettings.storageMinimalAvailablePercentage=10 \
  --set persistence.defaultClassReplicaCount=2 \
  --set csi.attacherReplicaCount=1 \
  --set csi.provisionerReplicaCount=1 \
  --set csi.resizerReplicaCount=1 \
  --set csi.snapshotterReplicaCount=1

echo "==> Waiting for Longhorn to be ready (up to 10 min)..."
kubectl -n longhorn-system rollout status deploy/longhorn-driver-deployer --timeout=600s

echo "==> Setting Longhorn as default StorageClass..."
kubectl patch storageclass local-path \
  -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}' \
  2>/dev/null || true

kubectl patch storageclass longhorn \
  -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

echo "==> Longhorn pods:"
kubectl get pods -n longhorn-system

echo ""
echo "Done. Longhorn UI accessible via port-forward:"
echo "  kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80"
