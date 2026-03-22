# Runbook — Kubernetes vanilla sur Proxmox

Déploiement from scratch d'un cluster Kubernetes 3 nœuds sur Proxmox VE avec stack GitOps complète.

## Architecture

| Composant | Valeur |
|---|---|
| Proxmox node | `pve` (192.168.1.90) |
| Control plane | `k8s-control-plane` — 192.168.1.209 |
| Worker 1 | `k8s-worker-1` — 192.168.1.202 |
| Worker 2 | `k8s-worker-2` — 192.168.1.203 |
| CNI | Cilium 1.17.x (kube-proxy replacement) |
| CSI | Longhorn 1.8.x (disque dédié /dev/sdb sur workers) |
| Load Balancer | MetalLB 0.14.x L2 — pool 192.168.1.210–230 |
| Ingress | Envoy Gateway v1.4.x (Gateway API) — IP 192.168.1.211 |
| TLS | cert-manager + Let's Encrypt DNS-01 Cloudflare |
| GitOps | ArgoCD 7.8.x — App of Apps |
| Monitoring | kube-prometheus-stack |
| Domaine | `*.home.slydien.com` |

---

## Prérequis

- Proxmox VE 8.x opérationnel
- SSH configuré : `ssh pve` → 192.168.1.90
- Terraform >= 1.5 installé localement
- `helm`, `kubectl`, `gh` installés localement
- Token API Cloudflare avec permission `Zone:DNS:Edit`
- Repo Git public créé (ex. `github.com/slydien/proxmox-k8s`)

---

## Phase 1 — Provisionner les VMs avec Terraform

```bash
cd terraform/

# Copier et remplir les secrets
cp terraform.tfvars.example terraform.tfvars
# Renseigner : proxmox_endpoint, proxmox_password, ssh_public_key, vm_password

# Uploader l'image Ubuntu (si pas déjà présente dans Proxmox)
../scripts/upload-ubuntu-image.sh

# Déployer les 3 VMs
terraform init
terraform apply
```

Résultat : 3 VMs cloud-init créées (IPs statiques, SSH key injectée).

Vérifier SSH sur les 3 nœuds :
```bash
ssh ubuntu@192.168.1.209
ssh ubuntu@192.168.1.202
ssh ubuntu@192.168.1.203
```

---

## Phase 2 — Bootstrap Kubernetes

```bash
cd kubernetes/bootstrap/

# Copier le kubeconfig (sera récupéré automatiquement après kubeadm init)
./bootstrap.sh
```

Ce script :
1. Copie et exécute `prepare-node.sh` sur les 3 nœuds en parallèle
   - swap off, modules kernel (overlay, br_netfilter), sysctl
   - Installation containerd + SystemdCgroup=true
   - Installation kubeadm/kubelet/kubectl 1.32
2. `kubeadm init` sur le control plane (sans kube-proxy — remplacé par Cilium)
3. `kubeadm join` sur worker-1 et worker-2
4. Récupère le kubeconfig dans `bootstrap/kubeconfig`

Vérifier (3 nœuds `NotReady` avant CNI) :
```bash
export KUBECONFIG=kubernetes/bootstrap/kubeconfig
kubectl get nodes
```

---

## Phase 3 — CNI Cilium

```bash
cd kubernetes/bootstrap/
./install-cilium.sh
```

Cilium remplace kube-proxy (eBPF). Hubble activé.

Vérifier :
```bash
kubectl get nodes          # 3x Ready
kubectl get pods -n kube-system -l k8s-app=cilium
kubectl exec -n kube-system ds/cilium -- cilium status --brief
```

---

## Phase 4 — CSI Longhorn

```bash
./install-longhorn.sh
```

Ce script :
1. Formate `/dev/sdb` sur worker-1 et worker-2 (`wipefs` + `mkfs.ext4`)
2. Monte à `/var/lib/longhorn`
3. Installe open-iscsi et nfs-common sur tous les nœuds
4. Installe Longhorn via Helm (2 réplicas, Longhorn = StorageClass par défaut)

Vérifier :
```bash
kubectl get nodes.longhorn.io -n longhorn-system
kubectl get storageclass
```

---

## Phase 5 — MetalLB

```bash
./install-metallb.sh
```

Configure le pool L2 `192.168.1.210–230`.

Vérifier :
```bash
kubectl get ipaddresspool -n metallb-system
```

---

## Phase 6 — ArgoCD

```bash
./install-argocd.sh https://github.com/slydien/proxmox-k8s
```

Ce script :
1. Installe ArgoCD via Helm (LoadBalancer sur 192.168.1.210, mode insecure)
2. Applique `kubernetes/apps/root-app.yaml` (App of Apps)

Récupérer le mot de passe admin initial :
```bash
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath='{.data.password}' | base64 -d
```

ArgoCD UI : http://192.168.1.210

---

## Phase 7 — cert-manager + Envoy Gateway (bootstrap)

Ces deux composants sont installés via scripts (pas ArgoCD) pour éviter le problème chicken-and-egg des CRDs.

```bash
./install-cert-manager.sh
./install-envoy-gateway.sh
```

### Créer le secret Cloudflare

```bash
kubectl create secret generic cloudflare-api-token \
  --from-literal=api-token=<TON_TOKEN> \
  -n cert-manager
```

### DNS Pi-hole (local)

Ajouter dans Pi-hole les entrées A vers 192.168.1.211 :
- `argocd.home.slydien.com`
- `grafana.home.slydien.com`
- `longhorn.home.slydien.com`

### Vérifier après sync ArgoCD

```bash
kubectl get clusterissuer                          # Ready=True
kubectl get gateway -n envoy-gateway-system        # Programmed=True
kubectl get certificate -n envoy-gateway-system    # Ready=True
kubectl get httproutes -A
```

ArgoCD HTTPS : https://argocd.home.slydien.com

---

## Phase 8 — Applications (ArgoCD gère tout)

Une fois ArgoCD synced, les applications suivantes se déploient automatiquement depuis `kubernetes/apps/` :

- **kube-prometheus-stack** : Prometheus + Grafana + Alertmanager
  - Grafana : https://grafana.home.slydien.com (admin/admin → changer le mot de passe)
- **Longhorn UI** : https://longhorn.home.slydien.com
- **NetworkPolicies** : default-deny-all + flux explicites sur tous les namespaces

Vérifier :
```bash
kubectl get applications -n argocd
kubectl get pods -n monitoring
kubectl get networkpolicies -A | grep default-deny
```

---

## Phase 9 — Validation

```bash
# Tous les nœuds Ready
kubectl get nodes

# Cilium OK
kubectl exec -n kube-system ds/cilium -- cilium status --brief

# Longhorn healthy
kubectl get volumes.longhorn.io -n longhorn-system

# Prometheus : 21/22 targets UP (etcd non exposé = normal)
# Vérifier via Grafana → Explore → Prometheus

# Test GitOps round-trip (< 2 min)
# Ajouter un manifest dans kubernetes/apps/, git push, mesurer le temps jusqu'au pod Running
```

---

## Opérations courantes

### Ajouter une application via ArgoCD

1. Créer un dossier dans `kubernetes/apps/<nom-app>/`
2. Ajouter un `Application` manifest ArgoCD ou des manifests Kubernetes directs
3. `git push` → ArgoCD sync automatique (~3 min ou forcer avec hard refresh)

### Forcer un sync ArgoCD

```bash
kubectl annotate application root -n argocd argocd.argoproj.io/refresh=hard --overwrite
```

### Ajouter un HTTPRoute (exposer une app)

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: mon-app
  namespace: mon-namespace
spec:
  parentRefs:
    - name: homelab
      namespace: envoy-gateway-system
      sectionName: https
  hostnames:
    - mon-app.home.slydien.com
  rules:
    - backendRefs:
        - name: mon-service
          port: 80
```

Puis ajouter l'entrée DNS dans Pi-hole → 192.168.1.211.

### Renouvellement TLS

Automatique via cert-manager. Vérifier :
```bash
kubectl get certificate -A
kubectl get certificaterequest -A
```

### Accès kubeconfig

```bash
export KUBECONFIG=/path/to/proxmox-k8s/kubernetes/bootstrap/kubeconfig
```

---

## Secrets à ne jamais commiter

| Secret | Namespace | Usage |
|---|---|---|
| `cloudflare-api-token` | cert-manager | DNS-01 ACME |
| `argocd-initial-admin-secret` | argocd | Supprimer après premier login |
| `terraform.tfvars` | local | Credentials Proxmox |

---

## Notes connues

- **kube-etcd DOWN dans Prometheus** : normal, kubeadm bind etcd sur 127.0.0.1 uniquement
- **cert-manager et Envoy Gateway** : installés via bootstrap scripts (pas ArgoCD) pour éviter le chicken-and-egg des CRDs
- **Envoy proxy ports** : le pod écoute sur 10080/10443 (non-privilégiés), pas 80/443 — important pour les NetworkPolicies
- **Cilium hostNetwork** : les pods hostNetwork (node-exporter, kubelet) nécessitent une règle egress sans `to` (pas `ipBlock`) pour être scrapés par Prometheus
