variable "private_dns_records" {
  type = map(object({
    resource_group_name = string
    dns_zone_name        = string
    name                 = string
    ttl                  = number
    records              = list(string)
  }))
}