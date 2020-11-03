resource "hcloud_ssh_key" "okd4" {
  name = "okd4"
  public_key = file(var.public_key_path)
}

data "template_file" "grub-bootstrap" {
  count = var.bootstrap_enabled ? 1 : 0
  template = file("${path.module}/tpl/40_custom.tpl")
  vars = {
    ignition_hostname = hcloud_server.ignition.ipv4_address
    server_role = "bootstrap"
    server_ip = hcloud_server.bootstrap[0].ipv4_address
    server_gateway = var.server_gateway
    server_netmask = var.server_netmask
    server_hostname = cloudflare_record.bootstrap[0].hostname
    server_nameserver = var.dns_server
  }
}

data "template_file" "grub-master" {
  count = var.master_count
  template = file("${path.module}/tpl/40_custom.tpl")
  vars = {
    ignition_hostname = "ignition.${var.cluster_name}.${var.base_domain}"
    server_role = "master"
    server_ip = hcloud_server.master[count.index].ipv4_address
    server_gateway = var.server_gateway
    server_netmask = var.server_netmask
    server_hostname = cloudflare_record.master[count.index].hostname
    server_nameserver = var.dns_server
  }
}

data "template_file" "grub-worker" {
  count = var.worker_count
  template = file("${path.module}/tpl/40_custom.tpl")
  vars = {
    ignition_hostname = "ignition.${var.cluster_name}.${var.base_domain}"
    server_role = "worker"
    server_ip = hcloud_server.worker[count.index].ipv4_address
    server_gateway = var.server_gateway
    server_netmask = var.server_netmask
    server_hostname = cloudflare_record.worker[count.index].hostname
    server_nameserver = var.dns_server
  }
}

