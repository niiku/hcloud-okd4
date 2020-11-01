#
# Hetzner
#
variable "hcloud_token" {
  description = "Hetzner Cloud API Token"
  type = string
}

#
# Cloudflare / DNS
#
variable "email" {
  description = "Cloudflare Account Email"
  type = string
}

variable "api_key" {
  description = "Cloudflare API Token"
  type = string
}

variable "cf_zone_id" {
  description = "Cloudflare Zone ID"
  type = string
}

#
# VM
#
variable "image" {
  type = string
  default = "centos-8"
}

variable "region" {
  description = "Create nodes in this regions"
  type = string
  default = "fsn1"
}

#
# Domain
#
variable "base_domain" {
  description = "Base domain for the cluster"
  type = string
}

variable cluster_name {
  type = string
  default = "okd"
}
#
# SSH
#
variable "public_key_path" {
  description = "Path to the public key to access OKD4 nodes"
  type = string
  default = "~/.ssh/id_rsa.pub"
}

variable "private_key_path" {
  description = "Path to the private key to access OKD4 nodes"
  type = string
  default = "~/.ssh/id_rsa"
}

#
# Ignition variables
#
variable ignition_enabled {
  type = bool
  default = true
}

variable ignition_server_type {
  type = string
  default = "cx11"
}

variable "openshift_installer_dir" {
  type = string
  default = "~/okd4/installer/"
}

variable "fcos_installer_initramfs" {
  description = "URL to the Fedora CoreOS installer initramfs"
  type = string
}

variable "fcos_installer_kernel" {
  description = "URL to the Fedora CoreOS installer kernel"
  type = string
}
variable "fcos_metal_bios" {
  description = "URL to the Fedora CoreOS metal bios archive"
  type = string
}
variable "fcos_rootfs" {
  description = "URL to the Fedora CoreOS rootfs"
  type = string
}

#
# Load Balancer variables
#
variable "load_balancer_type" {
  type = string
  default = "lb11"
}

variable "load_balancer_algorithm" {
  type = string
  default = "least_connections"
}
#
# Network variables
#
variable server_gateway {
  type = string
  default = "172.31.1.1"
}
variable server_netmask {
  type = string
  default = "255.255.255.255"
}
variable dns_server {
  type = string
  default = "1.1.1.1"
}

#
# Bootstrap variables
#
variable bootstrap_enabled {
  type = bool
  default = true
}

variable bootstrap_server_type {
  type = string
  default = "cx41"
}

#
# Master variables
#
variable master_server_type {
  type = string
  default = "cx41"
}

variable "master_count" {
  description = "Master node count"
  type = number
  default = 3
}

#
# Worker variables
#
variable worker_server_type {
  type = string
  default = "cx31"
}

variable "worker_count" {
  description = "Compute node count"
  type = number
  default = 2
}
variable "worker_storage_enabled" {
  type = bool
  default = false
}

variable "worker_storage_size" {
  type = number
  default = 100
}

variable "subdomains" {
  type = list(string)
  default = []
}
