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

resource "azurerm_public_ip" "public_ip" {
  name                = "pip-homelab-${var.environment}-weu"
  location            = data.azurerm_resource_group.default_resource_group.location
  resource_group_name = data.azurerm_resource_group.default_resource_group.name
  allocation_method   = "Static"
  sku                 = "Standard"
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

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = ["Get", "Set", "List"]
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "vm-ubuntu-homelab-${var.environment}-weu"
  location            = data.azurerm_resource_group.default_resource_group.location
  resource_group_name = data.azurerm_resource_group.default_resource_group.name
  size                = "Standard_B2pls_v2"
  admin_username      = "sysadmin"

  network_interface_ids = [
    azurerm_network_interface.nic.id
  ]

  os_disk {
    name                 = "osdisk-homelab"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "24_04-lts"
    version   = "latest"
  }
}

resource "azurerm_virtual_machine_extension" "kv_extension" {
  name                 = "keyvault-extension"
  virtual_machine_id   = azurerm_linux_virtual_machine.vm.id
  publisher            = "Microsoft.Azure.KeyVault"
  type                 = "KeyVaultForLinux"
  type_handler_version = "2.0"

  settings = <<SETTINGS
{
  "secretsManagementSettings": {
    "pollingIntervalInS": "3600",
    "certificateStoreLocation": "/var/lib/waagent/Microsoft.Azure.KeyVault/",
    "observedCertificates": [],
    "requireInitialSync": "true"
  }
}
SETTINGS
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

resource "azurerm_dns_a_record" "ssh_record" {
  name                = "ssh-test"
  zone_name           = azurerm_dns_zone.dns_zone.name
  resource_group_name = data.azurerm_resource_group.default_resource_group.name
  ttl                 = 300
  records             = [azurerm_public_ip.public_ip.ip_address]
}
