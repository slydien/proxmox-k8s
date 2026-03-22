#!/usr/bin/env bash
# Install cert-manager via Helm. Config (ClusterIssuer) is managed by ArgoCD.
set -euo pipefail

CERT_MANAGER_VERSION="v1.17.1"
export KUBECONFIG="$(dirname "${BASH_SOURCE[0]}")/kubeconfig"

echo "==> Adding cert-manager Helm repo..."
helm repo add jetstack https://charts.jetstack.io
helm repo update

echo "==> Installing cert-manager ${CERT_MANAGER_VERSION}..."
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version "${CERT_MANAGER_VERSION}" \
  --set crds.enabled=true \
  --wait

echo "==> cert-manager pods:"
kubectl get pods -n cert-manager

echo ""
echo "Done. Create the Cloudflare API token secret next:"
echo "  kubectl create secret generic cloudflare-api-token \\"
echo "    --namespace cert-manager \\"
echo "    --from-literal=api-token=<YOUR_TOKEN>"
