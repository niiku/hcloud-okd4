provider "hcloud" {
  token = var.hcloud_token
}

provider "cloudflare" {
  version = "~> 2.0"
  email = var.email
  api_key = var.api_key
}