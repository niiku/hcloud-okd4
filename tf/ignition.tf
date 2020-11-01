resource "hcloud_server" "ignition" {
  count = var.ignition_enabled ? 1 : 0
  name = "ignition.${var.cluster_name}.${var.base_domain}"
  image = var.image
  server_type = var.ignition_server_type
  keep_disk = true
  location = var.region
  ssh_keys = [
    hcloud_ssh_key.okd4.id]
}

resource "null_resource" "ignition_post_deploy" {
  count = var.ignition_enabled ? 1 : 0
  connection {
    host = hcloud_server.ignition[0].ipv4_address
    type = "ssh"
    user = "root"
    private_key = file(var.private_key_path)
  }


  provisioner "remote-exec" {
    inline = [
      "yum -y install httpd",
      "systemctl enable httpd",
      "systemctl start httpd",
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "curl ${var.fcos_installer_kernel} -o /var/www/html/fcos-installer-kernel",
      "curl ${var.fcos_installer_initramfs} -o /var/www/html/fcos-initramfs.img",
      "curl ${var.fcos_rootfs} -o /var/www/html/fcos-rootfs.img",
      "curl ${var.fcos_rootfs}.sig -o /var/www/html/fcos-rootfs.img.sig",
      "curl ${var.fcos_metal_bios} -o /var/www/html/fcos-metal-bios.raw.gz",
      "curl ${var.fcos_metal_bios}.sig -o /var/www/html/fcos-metal-bios.raw.gz.sig",
    ]
  }

  provisioner "file" {
    source = "${var.openshift_installer_dir}bootstrap.ign"
    destination = "/var/www/html/bootstrap.ign"
  }

  provisioner "file" {
    source = "${var.openshift_installer_dir}master.ign"
    destination = "/var/www/html/master.ign"
  }

  provisioner "file" {
    source = "${var.openshift_installer_dir}worker.ign"
    destination = "/var/www/html/worker.ign"
  }
}

resource "cloudflare_record" "ignition" {
  count = var.ignition_enabled ? 1 : 0
  zone_id = var.cf_zone_id
  name = "ignition.${var.cluster_name}.${var.base_domain}"
  value = hcloud_server.ignition[0].ipv4_address
  type = "A"
  ttl = 120
}

