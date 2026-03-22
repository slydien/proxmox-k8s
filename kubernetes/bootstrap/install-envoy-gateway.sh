#!/usr/bin/env bash
# Install Envoy Gateway via Helm. Config (Gateway, HTTPRoute) is managed by ArgoCD.
set -euo pipefail

ENVOY_GW_VERSION="v1.4.1"
export KUBECONFIG="$(dirname "${BASH_SOURCE[0]}")/kubeconfig"

echo "==> Installing Envoy Gateway ${ENVOY_GW_VERSION} (OCI registry)..."
helm install envoy-gateway \
  oci://docker.io/envoyproxy/gateway-helm \
  --version "${ENVOY_GW_VERSION}" \
  --namespace envoy-gateway-system \
  --create-namespace \
  --wait

echo "==> Envoy Gateway pods:"
kubectl get pods -n envoy-gateway-system

echo ""
echo "Done. Gateway API CRDs installed. ArgoCD will now sync Gateway/HTTPRoute resources."
