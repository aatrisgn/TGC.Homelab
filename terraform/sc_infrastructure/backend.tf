terraform {
  backend "s3" {
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true

    region = "fr-par"
    endpoints = {
      s3 = "https://s3.fr-par.scw.cloud"
    }
  }
}