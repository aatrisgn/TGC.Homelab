resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-homelab-${var.environment}-weu"
  address_space       = ["10.0.0.0/16"]
  location            = data.azurerm_resource_group.default_resource_group.location
  resource_group_name = data.azurerm_resource_group.default_resource_group.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "frp"
  address_prefixes     = ["10.0.1.0/24"]
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = data.azurerm_resource_group.default_resource_group.name
}

resource "azurerm_subnet" "app_gateway_subnet" {
  name                 = "app-gateway"
  address_prefixes     = ["10.0.2.0/24"]
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = data.azurerm_resource_group.default_resource_group.name
}

resource "azurerm_public_ip" "public_ip" {
  name                = "pip-homelab-${var.environment}-weu"
  location            = data.azurerm_resource_group.default_resource_group.location
  resource_group_name = data.azurerm_resource_group.default_resource_group.name
  allocation_method   = "Static"
  sku                 = "Standard"
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

resource "azurerm_lb_backend_address_pool" "frp_backend_pool" {
  loadbalancer_id    = azurerm_lb.default.id
  name               = "FrpBackEndAddressPool"
  virtual_network_id = azurerm_virtual_network.vnet.id
}

resource "azurerm_lb_backend_address_pool_address" "frp_backend_pool_address" {
  name                    = "frp-backend-address"
  backend_address_pool_id = azurerm_lb_backend_address_pool.frp_backend_pool.id
  //virtual_network_id      = azurerm_virtual_network.vnet.id
  ip_address = azurerm_linux_virtual_machine.vm.private_ip_address
}

resource "azurerm_lb_probe" "http_probe" {
  loadbalancer_id = azurerm_lb.default.id
  name            = "http-probe"
  port            = 80
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

  tcp_reset_enabled = true
}

# Network Security Group
resource "azurerm_network_security_group" "vm_nsg" {
  name                = "nsg-homelab-${var.environment}-weu"
  location            = data.azurerm_resource_group.default_resource_group.location
  resource_group_name = data.azurerm_resource_group.default_resource_group.name

  security_rule {
    name                       = "Allow-SSH-From-Trusted-IP"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "87.104.29.3"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-SSH-From-Trusted-IP-2"
    priority                   = 1100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "80.208.67.137"
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
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

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
    name                       = "Port-7700-access"
    priority                   = 960
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "7700"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Port-7600-access"
    priority                   = 970
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "7600"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Port-6000-6005"
    priority                   = 980
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "22"
    destination_port_range     = "6000-6005"
    source_address_prefix      = "87.104.29.3"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Port-80"
    priority                   = 900
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "87.104.29.3"
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
    source_address_prefix      = "87.104.29.3"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Port-443-2"
    priority                   = 1090
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "80.208.67.137"
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
  network_security_group_id = azurerm_network_security_group.vm_nsg.id
}

resource "azurerm_network_interface" "nic" {
  name                = "vm-nic"
  location            = data.azurerm_resource_group.default_resource_group.location
  resource_group_name = data.azurerm_resource_group.default_resource_group.name



  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id


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

resource "azurerm_role_assignment" "kv_secrets_reader" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.vm_uami.principal_id
}

resource "azurerm_role_assignment" "kv_certificate_reader" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Certificate User"
  principal_id         = azurerm_user_assigned_identity.vm_uami.principal_id
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

resource "azurerm_dns_a_record" "k8_api_record" {
  name                = "k8-api"
  zone_name           = azurerm_dns_zone.dns_zone.name
  resource_group_name = data.azurerm_resource_group.default_resource_group.name
  ttl                 = 300
  records             = [azurerm_public_ip.public_ip.ip_address]
}

resource "azurerm_dns_a_record" "ssh_record" {
  name                = "ssh-test"
  zone_name           = azurerm_dns_zone.dns_zone.name
  resource_group_name = data.azurerm_resource_group.default_resource_group.name
  ttl                 = 300
  records             = [azurerm_public_ip.public_ip.ip_address]
}

resource "azurerm_dns_a_record" "certtest_record" {
  name                = "certtest"
  zone_name           = azurerm_dns_zone.dns_zone.name
  resource_group_name = data.azurerm_resource_group.default_resource_group.name
  ttl                 = 300
  records             = [azurerm_public_ip.public_ip.ip_address]
}

resource "azurerm_dns_a_record" "certtest2_record" {
  name                = "certtest2"
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
  records             = [azurerm_public_ip.public_ip.ip_address]
}
