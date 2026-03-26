resource "azurerm_bastion_host" "bastion" {
  name                = "bas-bastion-${var.environment}-${var.location_shortcode}"
  location            = var.location
  resource_group_name = var.resource_group_name
  virtual_network_id  = var.virtual_network_id

  sku                = "Developer"
  copy_paste_enabled = true
}
