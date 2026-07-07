resource "azurerm_private_dns_a_record" "dns_records" {
  for_each            = var.private_dns_records
  name                = each.value.name
  zone_name           = each.value.dns_zone_name
  resource_group_name = data.azurerm_resource_group.rg[each.value.resource_group_name].name
  ttl                  = each.value.ttl
  records              = each.value.records
}