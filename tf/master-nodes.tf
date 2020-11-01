resource "hcloud_server" "master" {
  depends_on = [hcloud_server.bootstrap]
  count = var.master_count
  name = "master${count.index}.${var.cluster_name}.${var.base_domain}"
  image = var.image
  server_type = var.master_server_type
  keep_disk = true
  location = var.region
  ssh_keys = [
    hcloud_ssh_key.okd4.id]
}

resource "null_resource" "master_post_deploy" {
  count = var.master_count
  connection {
    host = hcloud_server.master[count.index].ipv4_address
    type = "ssh"
    user = "root"
    private_key = file(var.private_key_path)
  }

  provisioner "file" {
    content = data.template_file.grub-master[count.index].rendered
    destination = "/etc/grub.d/40_custom"
  }

  provisioner "remote-exec" {
    inline = [
      "curl http://ignition.${var.cluster_name}.${var.base_domain}/fcos-installer-kernel -o /boot/fcos-installer-kernel",
      "curl http://ignition.${var.cluster_name}.${var.base_domain}/fcos-initramfs.img -o /boot/fcos-initramfs.img",
      "curl http://ignition.${var.cluster_name}.${var.base_domain}/fcos-rootfs.img -o /boot/fcos-rootfs.img",
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

resource "cloudflare_record" "master" {
  count = var.master_count
  zone_id = var.cf_zone_id
  name = "master${count.index}.${var.cluster_name}"
  value = hcloud_server.master[count.index].ipv4_address
  type = "A"
  ttl = 120
}

resource "cloudflare_record" "etcd" {
  count = var.master_count
  zone_id = var.cf_zone_id
  name = "etcd-${count.index}.${var.cluster_name}"
  value = hcloud_server.master[count.index].ipv4_address
  type = "A"
  ttl = 120
}

resource "cloudflare_record" "etcd-srv" {
  count = var.master_count
  zone_id = var.cf_zone_id
  name   = "_etcd-server-ssl._tcp.${var.cluster_name}"
  type   = "SRV"

  data = {
    service  = "_etcd-server-ssl"
    proto    = "_tcp"
    name     = "okd"
    priority = 0
    weight   = 10
    port     = 2380
    target   = cloudflare_record.etcd[count.index].hostname
  }
}