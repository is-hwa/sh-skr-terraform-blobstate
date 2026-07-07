terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.74.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "TEST-AKS-RG"
    storage_account_name = "shteststate"
    container_name       = "tfstate"
  }
}

provider "azurerm" {
  features {}
}
