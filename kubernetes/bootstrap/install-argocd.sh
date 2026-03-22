#!/usr/bin/env bash
# Install ArgoCD and apply the root App of Apps.
set -euo pipefail

ARGOCD_VERSION="7.8.23"   # Helm chart version (ArgoCD v2.14.x)
REPO_URL="${1:?Usage: $0 <git-repo-url>}"   # e.g. https://github.com/user/k8s-homelab
export KUBECONFIG="$(dirname "${BASH_SOURCE[0]}")/kubeconfig"

echo "==> Adding ArgoCD Helm repo..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

echo "==> Installing ArgoCD ${ARGOCD_VERSION}..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

helm install argocd argo/argo-cd \
  --namespace argocd \
  --version "${ARGOCD_VERSION}" \
  --set server.service.type=LoadBalancer \
  --set configs.params."server\.insecure"=true \
  --wait

echo "==> ArgoCD pods:"
kubectl get pods -n argocd

echo "==> ArgoCD LoadBalancer IP:"
kubectl get svc -n argocd argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
echo ""

echo "==> Applying root App of Apps..."
sed "s|REPO_URL_PLACEHOLDER|${REPO_URL}|g" \
  "$(dirname "${BASH_SOURCE[0]}")/../apps/root-app.yaml" \
  | kubectl apply -f -

echo ""
echo "Done. ArgoCD admin password:"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
