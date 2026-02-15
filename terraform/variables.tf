variable "resource_group_name" {
  description = "Azure resource group to deploy resources into"
  type        = string
}

variable "environment" {
  description = "environment type"
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "The environment variable must be either 'DEV' or 'PROD'."
  }
}

variable "passphrase" {
    type = string
    sensitive = true
}