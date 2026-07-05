# resource "scaleway_domain_zone" "domain_zone" {
#   domain     = var.environment == "prd" ? "tgcportal.com" : "dev.tgcportal.com"
#   subdomain  = "homelab"
#   project_id = data.scaleway_account_project.default_project.id
# }

resource "scaleway_domain_record" "homelab_a_records" {
  for_each = toset(local.domain_records)

  dns_zone = "homelab.tgcportal.com"
  name     = each.key
  type     = "A"
  data     = "1.2.3.4"
  ttl      = 3600
}

resource "scaleway_vpc" "vpc01" {
  name       = "homelab-${var.environment}-vpc"
  tags       = [var.environment, "terraform"]
  project_id = data.scaleway_account_project.default_project.id
}

resource "scaleway_vpc_private_network" "pn_priv" {
  name       = "proxy"
  tags       = [var.environment, "terraform"]
  project_id = data.scaleway_account_project.default_project.id
  vpc_id     = scaleway_vpc.vpc01.id

  ipv4_subnet {
    subnet = "192.168.0.0/26"
  }
}
