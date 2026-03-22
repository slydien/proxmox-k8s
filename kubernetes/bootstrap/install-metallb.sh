#!/usr/bin/env bash
# Install MetalLB in L2 mode with IP pool 192.168.1.210-230.
set -euo pipefail

METALLB_VERSION="0.14.9"
export KUBECONFIG="$(dirname "${BASH_SOURCE[0]}")/kubeconfig"

echo "==> Adding MetalLB Helm repo..."
helm repo add metallb https://metallb.github.io/metallb
helm repo update

echo "==> Installing MetalLB ${METALLB_VERSION}..."
kubectl create namespace metallb-system --dry-run=client -o yaml | kubectl apply -f -

helm install metallb metallb/metallb \
  --namespace metallb-system \
  --version "${METALLB_VERSION}" \
  --wait

echo "==> Configuring L2 IP pool (192.168.1.210-230)..."
kubectl apply -f - <<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: homelab-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.1.210-192.168.1.230
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: homelab-l2
  namespace: metallb-system
spec:
  ipAddressPools:
  - homelab-pool
EOF

echo "==> MetalLB pods:"
kubectl get pods -n metallb-system

echo ""
echo "==> Testing with a LoadBalancer service..."
kubectl run test-lb --image=nginx --port=80 --restart=Never 2>/dev/null || true
kubectl expose pod test-lb --type=LoadBalancer --port=80 --name=test-lb-svc 2>/dev/null || true
sleep 5
EXTERNAL_IP=$(kubectl get svc test-lb-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
echo "    External IP assigned: ${EXTERNAL_IP}"
kubectl delete pod test-lb --ignore-not-found=true
kubectl delete svc test-lb-svc --ignore-not-found=true

echo ""
echo "Done. MetalLB ready — pool 192.168.1.210-230."
