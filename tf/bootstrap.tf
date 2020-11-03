resource "hcloud_server" "bootstrap" {
  count = var.bootstrap_enabled ? 1 : 0
  depends_on = [null_resource.ignition_post_deploy]
  name = "bootstrap.${var.cluster_name}.${var.base_domain}"
  image = var.image
  server_type = var.bootstrap_server_type
  keep_disk = true
  location = var.region
  ssh_keys = [
    hcloud_ssh_key.okd4.id]
}

resource "null_resource" "bootstrap_post_deploy" {
  count = var.bootstrap_enabled ? 1 : 0
  connection {
    host = hcloud_server.bootstrap[0].ipv4_address
    type = "ssh"
    user = "root"
    private_key = file(var.private_key_path)
  }

  provisioner "file" {
    content = data.template_file.grub-bootstrap[0].rendered
    destination = "/etc/grub.d/40_custom"
  }

  provisioner "remote-exec" {
    inline = [
      "curl http://${hcloud_server.ignition.ipv4_address}/fcos-installer-kernel -o /boot/fcos-installer-kernel",
      "curl http://${hcloud_server.ignition.ipv4_address}/fcos-initramfs.img -o /boot/fcos-initramfs.img",
      "curl http://${hcloud_server.ignition.ipv4_address}/fcos-rootfs.img -o /boot/rootfs.img",
      "grub2-set-default 2",
      "grub2-mkconfig --output=/boot/grub2/grub.cfg",
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "reboot",
    ]
    on_failure = continue
  }
}

resource "cloudflare_record" "bootstrap" {
  count = var.bootstrap_enabled ? 1 : 0
  zone_id = var.cf_zone_id
  name = "bootstrap.${var.cluster_name}"
  value = hcloud_server.bootstrap[0].ipv4_address
  type = "A"
  ttl = 120
}
