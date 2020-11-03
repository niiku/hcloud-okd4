provider "hcloud" {
  version = "~> 1.22"
  token = var.hcloud_token
}

provider "cloudflare" {
  version = "~> 2.0"
  email = var.cf_email
  api_key = var.cf_api_key
}