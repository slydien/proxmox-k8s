provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  username  = var.proxmox_username
  password  = var.proxmox_password
  insecure  = var.proxmox_insecure

  # SSH is required by the provider for disk import operations.
  # The node address must be directly reachable from this machine.
  ssh {
    agent       = var.proxmox_ssh_agent
    username    = var.proxmox_ssh_user
    private_key = var.proxmox_ssh_agent ? null : file(var.proxmox_ssh_private_key)

    node {
      name    = var.proxmox_node
      address = var.proxmox_ssh_host
    }
  }
}

# ── Ubuntu 24.04 cloud image ─────────────────────────────────────────────────
# The image must be uploaded to Proxmox beforehand via:
#   ./scripts/upload-ubuntu-image.sh <proxmox_ip>
#
# Terraform references the existing file — no outbound download from Proxmox.

data "proxmox_virtual_environment_file" "ubuntu_cloud_image" {
  node_name    = var.proxmox_node
  content_type = "iso"
  datastore_id = "local"
  file_name    = "ubuntu-24.04-cloudimg-amd64.img"
}

# ── Control plane ────────────────────────────────────────────────────────────

module "control_plane" {
  source = "./modules/vm"

  vm_id          = 201
  name           = "k8s-control-plane"
  node_name      = var.proxmox_node
  cores          = 4
  memory         = 8192
  disk_size      = 50
  ip_address     = "192.168.1.209/24"
  gateway        = var.gateway
  dns_servers    = var.dns_servers
  storage_pool   = var.storage_pool
  network_bridge = var.network_bridge
  image_id       = data.proxmox_virtual_environment_file.ubuntu_cloud_image.id
  ssh_public_key = var.ssh_public_key
  vm_password    = var.vm_password
  longhorn_disk  = false
}

# ── Worker 1 ─────────────────────────────────────────────────────────────────

module "worker_1" {
  source = "./modules/vm"

  vm_id              = 202
  name               = "k8s-worker-1"
  node_name          = var.proxmox_node
  cores              = 4
  memory             = 8192
  disk_size          = 100
  ip_address         = "192.168.1.202/24"
  gateway            = var.gateway
  dns_servers        = var.dns_servers
  storage_pool       = var.storage_pool
  network_bridge     = var.network_bridge
  image_id           = data.proxmox_virtual_environment_file.ubuntu_cloud_image.id
  ssh_public_key     = var.ssh_public_key
  vm_password        = var.vm_password
  longhorn_disk      = true
  longhorn_disk_size = 50
}

# ── Worker 2 ─────────────────────────────────────────────────────────────────

module "worker_2" {
  source = "./modules/vm"

  vm_id              = 203
  name               = "k8s-worker-2"
  node_name          = var.proxmox_node
  cores              = 4
  memory             = 8192
  disk_size          = 100
  ip_address         = "192.168.1.203/24"
  gateway            = var.gateway
  dns_servers        = var.dns_servers
  storage_pool       = var.storage_pool
  network_bridge     = var.network_bridge
  image_id           = data.proxmox_virtual_environment_file.ubuntu_cloud_image.id
  ssh_public_key     = var.ssh_public_key
  vm_password        = var.vm_password
  longhorn_disk      = true
  longhorn_disk_size = 50
}
