#!/usr/bin/env bash
# Install Cilium as CNI with full kube-proxy replacement.
# Run from your local machine with KUBECONFIG set.
set -euo pipefail

CONTROL_PLANE_IP="192.168.1.209"
CONTROL_PLANE_PORT="6443"
CILIUM_VERSION="1.17.2"   # latest stable — update if needed

export KUBECONFIG="$(dirname "${BASH_SOURCE[0]}")/kubeconfig"

echo "==> Adding Cilium Helm repo..."
helm repo add cilium https://helm.cilium.io/
helm repo update

echo "==> Installing Cilium ${CILIUM_VERSION}..."
helm install cilium cilium/cilium \
  --version "${CILIUM_VERSION}" \
  --namespace kube-system \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost="${CONTROL_PLANE_IP}" \
  --set k8sServicePort="${CONTROL_PLANE_PORT}" \
  --set ipam.mode=kubernetes \
  --set hubble.enabled=true \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true \
  --set operator.replicas=1

echo "==> Waiting for Cilium to be ready (up to 5 min)..."
kubectl -n kube-system rollout status daemonset/cilium --timeout=300s

echo "==> Cilium status:"
kubectl -n kube-system get pods -l k8s-app=cilium

echo ""
echo "==> Cluster nodes (should be Ready in ~30s):"
kubectl get nodes

echo ""
echo "Done. Run 'cilium status' if you have the Cilium CLI installed."
