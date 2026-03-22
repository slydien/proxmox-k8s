output "control_plane_ip" {
  value = "192.168.1.209"
}

output "worker_ips" {
  value = {
    worker_1 = "192.168.1.202"
    worker_2 = "192.168.1.203"
  }
}

output "ssh_commands" {
  value = {
    control_plane = "ssh ubuntu@192.168.1.209"
    worker_1      = "ssh ubuntu@192.168.1.202"
    worker_2      = "ssh ubuntu@192.168.1.203"
  }
}
