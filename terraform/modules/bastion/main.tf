resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = var.virtual_network_name
  address_prefixes     = [var.subnet_prefix]
}

resource "azurerm_public_ip" "bastion" {
  name                = "pip-bastion-${var.environment}-${var.location_shortcode}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "bastion" {
  name                = "bas-bastion-${var.environment}-${var.location_shortcode}"
  location            = var.location
  resource_group_name = var.resource_group_name
  virtual_network_id  = var.virtual_network_id

  sku                = "Developer"
  copy_paste_enabled = true
}
