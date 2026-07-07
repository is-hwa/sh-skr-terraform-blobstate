terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.74.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "tfstate-poc-sh"
    storage_account_name = "sttfpocsh01"
    container_name       = "tfstate"
  }
}

provider "azurerm" {
  features {}
}
