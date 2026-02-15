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


resource "azurerm_virtual_machine_extension" "kv_extension" {
  name               = "keyvault-extension"
  virtual_machine_id = azurerm_linux_virtual_machine.vm.id

  publisher = "Microsoft.Azure.KeyVault"
  type      = "KeyVaultForLinux"

  type_handler_version = "3.5"

  # Use UAMI to authenticate to Key Vault
  settings = jsonencode({
    authenticationSettings = {
      msiClientId = azurerm_user_assigned_identity.vm_uami.client_id
      # msiEndpoint is optional; default IMDS endpoint is used
    }
    secretsManagementSettings = {
      pollingIntervalInS       = "3600"
      requireInitialSync       = true
      certificateStoreLocation = "/var/lib/waagent/Microsoft.Azure.KeyVault/"
      observedCertificates = [ #https://kv-ath-homelab-dev-weu.vault.azure.net/certificates/test/fedd4be0c40342f8b4e8de86f6a1b455
        {
          url                      = "https://kv-ath-homelab-dev-weu.vault.azure.net/certificates/test/fedd4be0c40342f8b4e8de86f6a1b455",
          certificateStoreLocation = "/var/lib/waagent/Microsoft.Azure.KeyVault/app1"
        }

      ] # add cert secret IDs if you want auto-materialization
    }
  })

  # Ensure RBAC is in place before extension starts
  depends_on = [
    azurerm_role_assignment.kv_secrets_reader
  ]
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
