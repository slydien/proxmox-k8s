# TASKS — Kubernetes vanilla sur Proxmox

## Configuration retenue

| Paramètre | Valeur |
|---|---|
| Proxmox node | `pve` |
| Bridge réseau | `vmbr0` |
| Storage pool | `local-lvm` |
| IPs VMs | `192.168.1.209–203` |
| Gateway | `192.168.1.254` |
| MetalLB pool | `192.168.1.210–230` |
| Domaine | `*.home.slydien.com` |
| TLS | Let's Encrypt DNS-01 (Cloudflare) |
| Git repo | Public HTTPS |
| Secrets | `.env` / `.tfvars` locaux |

---

## Phase 1 — Terraform / Provisioning

- [x] **1.1** Créer la structure `terraform/` (main.tf, variables.tf, outputs.tf, versions.tf)
- [x] **1.2** Configurer le provider `bpg/proxmox`
- [x] **1.3** Télécharger l'image Ubuntu 24.04 cloud-init dans Proxmox via Terraform
- [x] **1.4** Créer la template VM via `proxmox_virtual_environment_download_file`
- [x] **1.5** Module `vm` : provisionner le control-plane (`192.168.1.209`, 4 vCPU, 8 Go, 50 Go)
- [x] **1.6** Module `vm` : provisionner worker-1 (`192.168.1.202`, 4 vCPU, 8 Go, 100 Go + 50 Go Longhorn)
- [x] **1.7** Module `vm` : provisionner worker-2 (`192.168.1.203`, 4 vCPU, 8 Go, 100 Go + 50 Go Longhorn)
- [x] **1.8** Configurer cloud-init : SSH key, hostname, réseau statique, DNS
- [x] **1.9** Créer `.env.example` et `terraform.tfvars.example` (sans secrets)
- [x] **1.10** Vérifier SSH sur les 3 VMs (runtime)

## Phase 2 — Bootstrap Kubernetes (kubeadm)

- [x] **2.1** Script de préparation des VMs : swap off, modules kernel, sysctl, containerd
- [x] **2.2** Installation kubeadm / kubelet / kubectl (dernière stable)
- [x] **2.3** `kubeadm init` sur le control-plane (config sans kube-proxy pour Cilium)
- [x] **2.4** `kubeadm join` sur worker-1 et worker-2
- [x] **2.5** Vérifier `kubectl get nodes` (3 nœuds `NotReady` — normal avant CNI)

## Phase 3 — CNI : Cilium

- [x] **3.1** Installer Cilium via Helm (remplacement kube-proxy activé)
- [x] **3.2** Cilium DaemonSet rolled out (3/3 pods Running)
- [x] **3.3** Vérifier `kubectl get nodes` (3 nœuds `Ready`)
- [x] **3.4** Vérifier CoreDNS opérationnel

## Phase 4 — CSI : Longhorn

- [x] **4.1** Préparer les disques dédiés sur worker-1 et worker-2
- [x] **4.2** Installer Longhorn via Helm
- [x] **4.3** Définir Longhorn comme StorageClass par défaut
- [x] **4.4** Vérifier les réplicas Longhorn (2 réplicas sur les workers)

## Phase 5 — MetalLB

- [x] **5.1** Installer MetalLB via Helm
- [x] **5.2** Configurer le pool L2 (`192.168.1.210–230`)
- [x] **5.3** Créer l'`IPAddressPool` et le `L2Advertisement`
- [x] **5.4** Tester avec un Service de type `LoadBalancer` (IP 192.168.1.210 assignée)

## Phase 6 — ArgoCD

- [ ] **6.1** Installer ArgoCD manuellement (`kubectl apply`)
- [ ] **6.2** Créer l'Application racine `root-app.yaml` (App of Apps)
- [ ] **6.3** Configurer la structure `kubernetes/apps/` dans le repo Git
- [ ] **6.4** Vérifier accès UI ArgoCD (via port-forward dans un premier temps)

## Phase 7 — Traefik + cert-manager (via ArgoCD)

- [ ] **7.1** Application ArgoCD : cert-manager (CRDs + controller)
- [ ] **7.2** Configurer le `ClusterIssuer` Let's Encrypt DNS-01 Cloudflare
- [ ] **7.3** Application ArgoCD : Traefik v3
- [ ] **7.4** Configurer IngressRoute ArgoCD avec TLS automatique
- [ ] **7.5** Vérifier certificat valide sur `argocd.home.slydien.com`

## Phase 8 — Applications restantes (via ArgoCD)

- [ ] **8.1** Application ArgoCD : kube-prometheus-stack
- [ ] **8.2** Configurer Ingress Grafana (`grafana.home.slydien.com`)
- [ ] **8.3** Configurer Ingress Longhorn UI (`longhorn.home.slydien.com`)
- [ ] **8.4** NetworkPolicy : default deny-all + flux explicites par namespace
- [ ] **8.5** Vérifier tous les dashboards Grafana (K8s, Longhorn, Cilium/Hubble)

## Phase 9 — Validation finale

- [ ] **9.1** Toutes les Applications ArgoCD en `Synced` + `Healthy`
- [ ] **9.2** Test déploiement applicatif Git → ArgoCD → cluster (< 2 min)
- [ ] **9.3** Vérifier `cilium status`, `longhorn`, métriques Prometheus
- [ ] **9.4** Documenter le runbook de déploiement from scratch

---

## Légende

- `[ ]` À faire
- `[~]` En cours
- `[x]` Terminé
- `[!]` Bloqué
