
resource "azurerm_network_ddos_protection_plan" "ddos" {
  name                = "ddos-plan-weu-001"
  location            = data.azurerm_resource_group.default_resource_group.location
  resource_group_name = data.azurerm_resource_group.default_resource_group.name
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-homelab-${var.environment}-weu"
  address_space       = ["10.0.0.0/16"]
  location            = data.azurerm_resource_group.default_resource_group.location
  resource_group_name = data.azurerm_resource_group.default_resource_group.name

  ddos_protection_plan {
    id     = azurerm_network_ddos_protection_plan.ddos.id
    enable = true
  }
}

resource "azurerm_subnet" "load_balancer_subnet" {
  name                 = "loadbalancer"
  address_prefixes     = ["10.0.2.0/24"]
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = data.azurerm_resource_group.default_resource_group.name
}

resource "azurerm_public_ip" "lb_pip" {
  name                = "pip-loadbalancer-homelab-${var.environment}-weu"
  resource_group_name = data.azurerm_resource_group.default_resource_group.name
  location            = data.azurerm_resource_group.default_resource_group.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_lb" "default" {
  name                = "lb-homelab-${var.environment}-weu"
  location            = data.azurerm_resource_group.default_resource_group.location
  resource_group_name = data.azurerm_resource_group.default_resource_group.name

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.lb_pip.id
  }
}

module "bastion" {
  source = "./modules/bastion"

  resource_group_name  = data.azurerm_resource_group.default_resource_group.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  subnet_prefix        = "10.0.3.0/26"
  location             = data.azurerm_resource_group.default_resource_group.location
  location_shortcode   = "weu"
  environment          = var.environment
}

resource "azurerm_lb_backend_address_pool" "frp_backend_pool" {
  loadbalancer_id = azurerm_lb.default.id
  name            = "FrpBackEndAddressPool"
}

resource "azurerm_lb_probe" "http_probe" {
  loadbalancer_id = azurerm_lb.default.id
  name            = "http-probe"
  port            = 7500
}

resource "azurerm_lb_rule" "http_rule" {
  loadbalancer_id                = azurerm_lb.default.id
  name                           = "http"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.frp_backend_pool.id]
  probe_id                       = azurerm_lb_probe.http_probe.id

  tcp_reset_enabled     = true
  disable_outbound_snat = true
}

resource "azurerm_lb_rule" "frp_rule" {
  loadbalancer_id                = azurerm_lb.default.id
  name                           = "frp"
  protocol                       = "Tcp"
  frontend_port                  = 7500
  backend_port                   = 7500
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.frp_backend_pool.id]
  probe_id                       = azurerm_lb_probe.http_probe.id

  tcp_reset_enabled     = true
  disable_outbound_snat = true
}

resource "azurerm_lb_rule" "https_rule" {
  loadbalancer_id                = azurerm_lb.default.id
  name                           = "https"
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.frp_backend_pool.id]
  probe_id                       = azurerm_lb_probe.http_probe.id

  tcp_reset_enabled     = true
  disable_outbound_snat = true
}

resource "azurerm_network_security_group" "vm_lb_nsg" {
  name                = "nsg-loadbalancer-homelab-${var.environment}-weu"
  location            = data.azurerm_resource_group.default_resource_group.location
  resource_group_name = data.azurerm_resource_group.default_resource_group.name

  security_rule {
    name                       = "Port-80-access"
    priority                   = 950
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Port-7500-access"
    priority                   = 990
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "7500"
    source_address_prefix      = "80.208.67.137"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Port-443"
    priority                   = 890
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-Internet-Outbound"
    priority                   = 4090
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }
}

resource "azurerm_network_interface_security_group_association" "nic_nsg" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.vm_lb_nsg.id
}

resource "azurerm_network_interface_backend_address_pool_association" "lb_frp_backend_pool_association" {
  network_interface_id    = azurerm_network_interface.nic.id
  ip_configuration_name   = azurerm_network_interface.nic.ip_configuration[0].name
  backend_address_pool_id = azurerm_lb_backend_address_pool.frp_backend_pool.id
}

resource "azurerm_network_interface" "nic" {
  name                = "vm-nic"
  location            = data.azurerm_resource_group.default_resource_group.location
  resource_group_name = data.azurerm_resource_group.default_resource_group.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.load_balancer_subnet.id
    private_ip_address_allocation = "Static"
  }
}

resource "azurerm_key_vault" "kv" {
  name                       = "kv-ath-homelab-${var.environment}-weu"
  location                   = data.azurerm_resource_group.default_resource_group.location
  resource_group_name        = data.azurerm_resource_group.default_resource_group.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  purge_protection_enabled   = false
  soft_delete_retention_days = 7
  rbac_authorization_enabled = true
}

resource "azurerm_role_assignment" "spn_kv_access" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "tls_private_key" "vm" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_user_assigned_identity" "vm_uami" {
  name                = "mi-homelab-vm-frp"
  location            = data.azurerm_resource_group.default_resource_group.location
  resource_group_name = data.azurerm_resource_group.default_resource_group.name
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "vm-ubuntu-homelab-${var.environment}-weu"
  location            = data.azurerm_resource_group.default_resource_group.location
  resource_group_name = data.azurerm_resource_group.default_resource_group.name
  size                = "Standard_B2pls_v2"
  admin_username      = "sysadmin"



  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.vm_uami.id]
  }

  network_interface_ids = [
    azurerm_network_interface.nic.id
  ]

  os_disk {
    name                 = "osdisk-homelab"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }


  admin_ssh_key {
    username   = "sysadmin"
    public_key = tls_private_key.vm.public_key_openssh
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server-arm64"
    version   = "latest"
  }
}

resource "azurerm_key_vault_secret" "ssh_private" {
  name         = "vm-frp-ssh-private"
  key_vault_id = azurerm_key_vault.kv.id
  value        = tls_private_key.vm.private_key_pem
  content_type = "application/x-pem-file"

  depends_on = [azurerm_role_assignment.spn_kv_access]
}

resource "azurerm_key_vault_secret" "ssh_public" {
  name         = "vm-frp-ssh-public"
  key_vault_id = azurerm_key_vault.kv.id
  value        = tls_private_key.vm.public_key_openssh
  content_type = "text/plain"

  depends_on = [azurerm_role_assignment.spn_kv_access]
}

resource "azurerm_dns_zone" "dns_zone" {
  name                = "homelab.tgcportal.com"
  resource_group_name = data.azurerm_resource_group.default_resource_group.name
}

resource "azurerm_dns_a_record" "vm_record" {
  name                = "vm-frp"
  zone_name           = azurerm_dns_zone.dns_zone.name
  resource_group_name = data.azurerm_resource_group.default_resource_group.name
  ttl                 = 300
  records             = [azurerm_public_ip.public_ip.ip_address]
}

resource "azurerm_dns_a_record" "argocd_record" {
  name                = "argocd"
  zone_name           = azurerm_dns_zone.dns_zone.name
  resource_group_name = data.azurerm_resource_group.default_resource_group.name
  ttl                 = 300
  records             = [azurerm_public_ip.lb_pip.ip_address]
}
