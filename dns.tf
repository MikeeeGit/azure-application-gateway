resource "azurerm_private_dns_zone" "backend" {
  count               = var.backend_dns_zone == null ? 0 : 1
  name                = var.backend_dns_zone
  resource_group_name = azurerm_resource_group.appgw.name
  tags                = local.tags
  lifecycle {
    precondition {
      condition     = length(distinct(values(local.dns_links))) == length(local.dns_links)
      error_message = "Additional DNS links must not duplicate the automatic gateway VNet link."
    }
  }
}
resource "azurerm_private_dns_a_record" "backend" {
  for_each            = var.backend_dns_records
  name                = each.key
  zone_name           = azurerm_private_dns_zone.backend[0].name
  resource_group_name = azurerm_resource_group.appgw.name
  ttl                 = each.value.ttl
  records             = each.value.ip_addresses
  tags                = local.tags
}
resource "azurerm_private_dns_zone_virtual_network_link" "backend" {
  for_each              = local.dns_links
  name                  = "${local.label}-${each.key}-backend-dns"
  resource_group_name   = azurerm_resource_group.appgw.name
  private_dns_zone_name = azurerm_private_dns_zone.backend[0].name
  virtual_network_id    = each.value
  registration_enabled  = false
  tags                  = local.tags
}
resource "azurerm_private_dns_zone_virtual_network_link" "key_vault" {
  count                 = var.key_vault_private_dns_link == null ? 0 : 1
  provider              = azurerm.certificates
  name                  = var.key_vault_private_dns_link.link_name
  resource_group_name   = var.key_vault_private_dns_link.resource_group_name
  private_dns_zone_name = var.key_vault_private_dns_link.zone_name
  virtual_network_id    = local.network.virtual_network_id
  registration_enabled  = false
  tags                  = local.tags
}
