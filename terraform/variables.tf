# ── Proxmox connection ───────────────────────────────────────────────────────

variable "proxmox_endpoint" {
  type        = string
  description = "Proxmox API endpoint, e.g. https://192.168.1.x:8006/"
}

variable "proxmox_username" {
  type        = string
  description = "Proxmox API user, e.g. root@pam"
  default     = "root@pam"
}

variable "proxmox_password" {
  type        = string
  sensitive   = true
  description = "Proxmox API password"
}

variable "proxmox_insecure" {
  type        = bool
  default     = true
  description = "Skip TLS verification (Proxmox self-signed cert)"
}

variable "proxmox_node" {
  type        = string
  default     = "pve1"
  description = "Proxmox node name"
}

# ── SSH (required for disk import operations) ─────────────────────────────────

variable "proxmox_ssh_host" {
  type        = string
  description = "IP or hostname of the Proxmox node reachable via SSH from this machine"
}

variable "proxmox_ssh_user" {
  type        = string
  default     = "root"
  description = "SSH user on the Proxmox node"
}

variable "proxmox_ssh_agent" {
  type        = bool
  default     = false
  description = "Use SSH agent for authentication"
}

variable "proxmox_ssh_private_key" {
  type        = string
  default     = "~/.ssh/id_ed25519"
  description = "Path to SSH private key (used when proxmox_ssh_agent = false)"
}

# ── Storage / network ────────────────────────────────────────────────────────

variable "storage_pool" {
  type        = string
  default     = "local-lvm"
  description = "Proxmox storage pool for VM disks"
}

variable "network_bridge" {
  type        = string
  default     = "vmbr0"
  description = "Proxmox network bridge"
}

# ── Network ──────────────────────────────────────────────────────────────────

variable "gateway" {
  type    = string
  default = "192.168.1.254"
}

variable "dns_servers" {
  type    = list(string)
  default = ["192.168.1.254", "8.8.8.8"]
}

# ── VM credentials ───────────────────────────────────────────────────────────

variable "ssh_public_key" {
  type        = string
  description = "SSH public key injected into every VM (ubuntu user)"
}

variable "vm_password" {
  type        = string
  sensitive   = true
  description = "Password for the ubuntu user (leave empty to disable password auth)"
  default     = ""
}

# ── Ubuntu cloud image ───────────────────────────────────────────────────────
# The image is uploaded manually via scripts/upload-ubuntu-image.sh
# No URL/checksum variable needed — Terraform uses a data source.
