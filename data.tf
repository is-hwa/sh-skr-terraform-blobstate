data "azurerm_resource_group" "rg" {
  for_each = toset([for r in var.private_dns_records : r.resource_group_name])
  name     = each.key
}