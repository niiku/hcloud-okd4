
resource "hcloud_server" "worker" {
  depends_on = [hcloud_server.master]
  count = var.worker_count
  name = "worker${count.index}.${var.cluster_name}.${var.base_domain}"
  image = var.image
  server_type = var.worker_server_type
  keep_disk = true
  location = var.region
  ssh_keys = [
    hcloud_ssh_key.okd4.id]
}

resource "hcloud_volume" "storage" {
  count = var.worker_storage_enabled ? var.worker_count : 0
  name = "storage${count.index}.${var.cluster_name}.${var.base_domain}"
  size = 100
  server_id = hcloud_server.worker[count.index].id
  automount = false
}

resource "null_resource" "worker_post_deploy" {
  count = var.worker_count
  connection {
    host = hcloud_server.worker[count.index].ipv4_address
    type = "ssh"
    user = "root"
    private_key = file(var.private_key_path)
  }

  provisioner "file" {
    content = data.template_file.grub-worker[count.index].rendered
    destination = "/etc/grub.d/40_custom"
  }

  provisioner "remote-exec" {
    inline = [
      "curl http://${hcloud_server.ignition[0].ipv4_address}/fcos-installer-kernel -o /boot/fcos-installer-kernel",
      "curl http://${hcloud_server.ignition[0].ipv4_address}/fcos-initramfs.img -o /boot/fcos-initramfs.img",
      "curl http://${hcloud_server.ignition[0].ipv4_address}/fcos-rootfs.img -o /boot/fcos-rootfs.img",
      "grub2-set-default 2",
      "grub2-mkconfig --output=/boot/grub2/grub.cfg",
    ]
  }

//  provisioner "remote-exec" {
//    inline = [
//      "reboot",
//    ]
//    on_failure = continue
//  }
}

resource "cloudflare_record" "worker" {
  count = var.worker_count
  zone_id = var.cf_zone_id
  name = "worker${count.index}.${var.cluster_name}"
  value = hcloud_server.worker[count.index].ipv4_address
  type = "A"
  ttl = 120
}
