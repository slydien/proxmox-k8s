resource "proxmox_virtual_environment_vm" "this" {
  vm_id     = var.vm_id
  name      = var.name
  node_name = var.node_name

  description = "Managed by Terraform — k8s homelab"
  tags        = ["k8s", "terraform"]

  started      = true
  on_boot      = true
  stop_on_destroy = true

  # ── CPU ────────────────────────────────────────────────────────────────────
  cpu {
    cores = var.cores
    type  = "x86-64-v2-AES"  # Modern CPU type, improves performance vs kvm64
  }

  # ── Memory ─────────────────────────────────────────────────────────────────
  memory {
    dedicated = var.memory
  }

  # ── QEMU guest agent ───────────────────────────────────────────────────────
  # Disabled during provisioning — qemu-guest-agent is installed via cloud-init
  # on first boot. Re-enable after VMs are up if needed.
  agent {
    enabled = false
  }

  # ── Boot disk (cloned from Ubuntu cloud image) ─────────────────────────────
  disk {
    datastore_id = var.storage_pool
    file_id      = var.image_id
    interface    = "scsi0"
    size         = var.disk_size
    discard      = "on"
    ssd          = true
    file_format  = "raw"
  }

  # ── Longhorn dedicated disk (workers only) ─────────────────────────────────
  # Mounted at /dev/sdb inside the VM; Longhorn will use it as block storage.
  dynamic "disk" {
    for_each = var.longhorn_disk ? [1] : []
    content {
      datastore_id = var.storage_pool
      interface    = "scsi1"
      size         = var.longhorn_disk_size
      discard      = "on"
      ssd          = true
      file_format  = "raw"
    }
  }

  # ── Network ────────────────────────────────────────────────────────────────
  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  # ── OS type ────────────────────────────────────────────────────────────────
  operating_system {
    type = "l26"  # Linux 2.6+
  }

  # ── SCSI controller ────────────────────────────────────────────────────────
  scsi_hardware = "virtio-scsi-single"

  # ── Serial console (required for cloud-init on some images) ────────────────
  serial_device {}

  # ── Boot order ─────────────────────────────────────────────────────────────
  boot_order = ["scsi0"]

  # ── cloud-init ─────────────────────────────────────────────────────────────
  initialization {
    ip_config {
      ipv4 {
        address = var.ip_address
        gateway = var.gateway
      }
    }

    dns {
      servers = var.dns_servers
    }

    user_account {
      username = "ubuntu"
      password = var.vm_password != "" ? var.vm_password : null
      keys     = [trimspace(var.ssh_public_key)]
    }
  }

  # Only ignore user_account changes (password/keys) to avoid re-triggering
  # cloud-init on existing VMs. IP and DNS changes will update the Proxmox
  # cloud-init drive; to apply them inside the VM, run:
  #   cloud-init clean && reboot
  lifecycle {
    ignore_changes = [initialization[0].user_account]
  }
}
