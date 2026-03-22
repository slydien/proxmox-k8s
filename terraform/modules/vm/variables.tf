variable "vm_id" {
  type        = number
  description = "Proxmox VM ID (must be unique)"
}

variable "name" {
  type        = string
  description = "VM hostname"
}

variable "node_name" {
  type        = string
  description = "Proxmox node to create the VM on"
}

variable "cores" {
  type    = number
  default = 2
}

variable "memory" {
  type        = number
  description = "RAM in MiB"
  default     = 4096
}

variable "disk_size" {
  type        = number
  description = "OS disk size in GiB"
}

variable "ip_address" {
  type        = string
  description = "Static IP with prefix, e.g. 192.168.1.201/24"
}

variable "gateway" {
  type = string
}

variable "dns_servers" {
  type    = list(string)
  default = ["8.8.8.8"]
}

variable "storage_pool" {
  type    = string
  default = "local-lvm"
}

variable "network_bridge" {
  type    = string
  default = "vmbr0"
}

variable "image_id" {
  type        = string
  description = "ID of the downloaded cloud image (proxmox_virtual_environment_download_file.id)"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key for the ubuntu user"
}

variable "vm_password" {
  type      = string
  sensitive = true
  default   = ""
}

# ── Longhorn dedicated disk ──────────────────────────────────────────────────

variable "longhorn_disk" {
  type        = bool
  default     = false
  description = "Whether to attach a second dedicated disk for Longhorn storage"
}

variable "longhorn_disk_size" {
  type        = number
  default     = 50
  description = "Longhorn disk size in GiB (only used when longhorn_disk = true)"
}
