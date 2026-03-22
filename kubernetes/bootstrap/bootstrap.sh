#!/usr/bin/env bash
# Full bootstrap sequence — run from your local machine.
# Prerequisites: SSH access to all 3 nodes, scp available.
set -euo pipefail

CONTROL_PLANE="192.168.1.209"
WORKER_1="192.168.1.202"
WORKER_2="192.168.1.203"
SSH_USER="ubuntu"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ssh_exec() {
  local host="$1"; shift
  ssh -o StrictHostKeyChecking=no "${SSH_USER}@${host}" "$@"
}

scp_file() {
  local src="$1" host="$2" dst="$3"
  scp -o StrictHostKeyChecking=no "$src" "${SSH_USER}@${host}:${dst}"
}

echo "==> Copying prepare-node.sh to all nodes..."
for host in "$CONTROL_PLANE" "$WORKER_1" "$WORKER_2"; do
  scp_file "${SCRIPT_DIR}/prepare-node.sh" "$host" "/tmp/prepare-node.sh"
done

echo "==> Running prepare-node.sh on all nodes (in parallel)..."
for host in "$CONTROL_PLANE" "$WORKER_1" "$WORKER_2"; do
  ssh_exec "$host" "sudo bash /tmp/prepare-node.sh" &
done
wait
echo "    All nodes prepared."

echo "==> Copying kubeadm config to control-plane..."
scp_file "${SCRIPT_DIR}/kubeadm-config.yaml" "$CONTROL_PLANE" "/tmp/kubeadm-config.yaml"

echo "==> Running kubeadm init on control-plane..."
ssh_exec "$CONTROL_PLANE" "sudo kubeadm init --config /tmp/kubeadm-config.yaml --skip-phases=addon/kube-proxy 2>&1 | tee /tmp/kubeadm-init.log"

echo "==> Setting up kubeconfig on control-plane..."
ssh_exec "$CONTROL_PLANE" "mkdir -p \$HOME/.kube && sudo cp /etc/kubernetes/admin.conf \$HOME/.kube/config && sudo chown \$(id -u):\$(id -g) \$HOME/.kube/config"

echo "==> Retrieving join command..."
JOIN_CMD=$(ssh_exec "$CONTROL_PLANE" "sudo kubeadm token create --print-join-command")

echo "==> Joining worker-1..."
ssh_exec "$WORKER_1" "sudo ${JOIN_CMD}"

echo "==> Joining worker-2..."
ssh_exec "$WORKER_2" "sudo ${JOIN_CMD}"

echo "==> Copying kubeconfig locally..."
mkdir -p "${SCRIPT_DIR}"
scp -o StrictHostKeyChecking=no "${SSH_USER}@${CONTROL_PLANE}:/home/${SSH_USER}/.kube/config" "${SCRIPT_DIR}/kubeconfig"
export KUBECONFIG="${SCRIPT_DIR}/kubeconfig"

echo "==> Cluster nodes:"
kubectl get nodes

echo ""
echo "Bootstrap complete. Nodes are NotReady until Cilium is installed."
echo "Export kubeconfig:"
echo "  export KUBECONFIG=${SCRIPT_DIR}/kubeconfig"
