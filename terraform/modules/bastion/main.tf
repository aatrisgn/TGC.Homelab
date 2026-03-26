
# -----------------------------
# Bastion Subnet (must be named AzureBastionSubnet)
# Minimum size /26 recommended
# -----------------------------
resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = var.virtual_network_name
  address_prefixes     = [var.subnet_prefix]
}

# -----------------------------
# Public IP for Bastion
# Must be Standard SKU and Static
# -----------------------------
resource "azurerm_public_ip" "bastion" {
  name                = "pip-bastion-${var.environment}-${var.location_shortcode}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# -----------------------------
# Bastion Host (Developer SKU)
# -----------------------------
resource "azurerm_bastion_host" "bastion" {
  name                = "bas-bastion-${var.environment}-${var.location_shortcode}"
  location            = var.location
  resource_group_name = var.resource_group_name

  sku = "Developer"
  copy_paste_enabled = true

  ip_configuration {
    name                 = "bastion-ipconfig"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}
