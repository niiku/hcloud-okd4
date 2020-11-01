resource "hcloud_load_balancer" "okd_cluster" {
  name = "lb.${var.cluster_name}.${var.base_domain}"
  load_balancer_type = var.load_balancer_type
  location = var.region
  algorithm {
    type = var.load_balancer_algorithm
  }
  dynamic "target" {
    for_each = hcloud_server.bootstrap
    content {
      type = "server"
      server_id = target.value["id"]
    }
  }
  dynamic "target" {
    for_each = hcloud_server.master
    content {
      type = "server"
      server_id = target.value["id"]
    }
  }
  dynamic "target" {
    for_each = hcloud_server.worker
    content {
      type = "server"
      server_id = target.value["id"]
    }
  }
}

resource "hcloud_load_balancer_service" "http" {
  depends_on = [hcloud_load_balancer.okd_cluster]
  load_balancer_id = hcloud_load_balancer.okd_cluster.id
  protocol = "tcp"
  listen_port = 80
  destination_port = 80
  proxyprotocol = false
  health_check {
    protocol = "tcp"
    port = 80
    interval = 5
    timeout = 3
    retries = 2
  }
}

resource "hcloud_load_balancer_service" "https" {
  depends_on = [hcloud_load_balancer_service.http]
  load_balancer_id = hcloud_load_balancer.okd_cluster.id
  protocol = "tcp"
  listen_port = 443
  destination_port = 443
  proxyprotocol = false
  health_check {
    protocol = "tcp"
    port = 443
    interval = 5
    timeout = 3
    retries = 2
  }
}

resource "hcloud_load_balancer_service" "api" {
  depends_on = [hcloud_load_balancer_service.https]
  load_balancer_id = hcloud_load_balancer.okd_cluster.id
  protocol = "tcp"
  listen_port = 6443
  destination_port = 6443
  proxyprotocol = false
  health_check {
    protocol = "tcp"
    port = 6443
    interval = 5
    timeout = 3
    retries = 2
  }
}

resource "hcloud_load_balancer_service" "api-alt" {
  depends_on = [hcloud_load_balancer_service.https]
  load_balancer_id = hcloud_load_balancer.okd_cluster.id
  protocol = "tcp"
  listen_port = 8443
  destination_port = 6443
  proxyprotocol = false
  health_check {
    protocol = "tcp"
    port = 6443
    interval = 5
    timeout = 3
    retries = 2
  }
}

resource "hcloud_load_balancer_service" "machine_config" {
  depends_on = [hcloud_load_balancer_service.api]
  load_balancer_id = hcloud_load_balancer.okd_cluster.id
  protocol = "tcp"
  listen_port = 22623
  destination_port = 22623
  proxyprotocol = false
  health_check {
    protocol = "tcp"
    port = 22623
    interval = 5
    timeout = 3
    retries = 2
  }
}

resource "cloudflare_record" "lb" {
  zone_id = var.cf_zone_id
  name = "lb.${var.cluster_name}"
  value = hcloud_load_balancer.okd_cluster.ipv4
  type = "A"
  ttl = 120
}

resource "cloudflare_record" "api" {
  zone_id = var.cf_zone_id
  name = "api.${var.cluster_name}"
  value = hcloud_load_balancer.okd_cluster.ipv4
  type = "A"
  ttl = 120
}

resource "cloudflare_record" "api-int" {
  zone_id = var.cf_zone_id
  name = "api-int.${var.cluster_name}"
  value = hcloud_load_balancer.okd_cluster.ipv4
  type = "A"
  ttl = 120
}

resource "cloudflare_record" "apps" {
  zone_id = var.cf_zone_id
  name = "apps.${var.cluster_name}"
  value = hcloud_load_balancer.okd_cluster.ipv4
  type = "A"
  ttl = 120
}

resource "cloudflare_record" "apps-wildcard" {
  zone_id = var.cf_zone_id
  name = "*.apps.${var.cluster_name}"
  value = hcloud_load_balancer.okd_cluster.ipv4
  type = "A"
  ttl = 120
}

resource "cloudflare_record" "subdomains" {
  for_each = toset(var.subdomains)
  zone_id = var.cf_zone_id
  name = each.value
  value = hcloud_load_balancer.okd_cluster.ipv4
  type = "A"
  ttl = 120
}
