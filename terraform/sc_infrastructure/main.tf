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
  data     = scaleway_instance_ip.public_ip.address
  ttl      = 3600
}

resource "scaleway_vpc" "vpc01" {
  name       = "homelab-${var.environment}-vpc"
  tags       = [var.environment, "homelab", "terraform"]
  project_id = data.scaleway_account_project.default_project.id
}

resource "scaleway_vpc_private_network" "pn_priv" {
  name       = "proxy"
  tags       = [var.environment, "homelab", "terraform"]
  project_id = data.scaleway_account_project.default_project.id
  vpc_id     = scaleway_vpc.vpc01.id

  ipv4_subnet {
    subnet = "192.168.0.0/26"
  }
}

resource "scaleway_instance_ip" "public_ip" {
  project_id = data.scaleway_account_project.default_project.id
}

resource "scaleway_instance_server" "proxy_server" {
  name       = "sis_proxy-${var.environment}_01"
  type       = "PLAY2-PICO"
  image      = "ubuntu_jammy"
  ip_id      = scaleway_instance_ip.public_ip.id
  project_id = data.scaleway_account_project.default_project.id
  tags       = [var.environment, "homelab", "terraform"]

  security_group_id = scaleway_instance_security_group.security_group.id


  user_data = {
    cloud-init = <<-EOF
      #cloud-config
      users:
        - name: root
          ssh_authorized_keys:
            - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEQ2kH/HLLSt23tf6uH03HTh3dgbpi0QEnLV5sW0cXuL asgerarnbjornthyregod@Asgers-MacBook-Pro.local
    EOF
  }

  private_network {
    pn_id = scaleway_vpc_private_network.pn_priv.id
  }
}

resource "scaleway_instance_security_group" "security_group" {
  inbound_default_policy  = "drop"
  outbound_default_policy = "accept"
  project_id              = data.scaleway_account_project.default_project.id

  inbound_rule {
    action = "accept"
    port   = "7500"
  }

  inbound_rule {
    action = "accept"
    port   = "80"
  }

  inbound_rule {
    action = "accept"
    port   = "22"
  }

  inbound_rule {
    action = "accept"
    port   = "443"
  }
}
