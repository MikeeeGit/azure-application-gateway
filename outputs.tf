output "application_gateway_id" {
  value = azurerm_application_gateway.appgw.id
}
output "application_gateway_name" {
  value = azurerm_application_gateway.appgw.name
}
output "resource_group_name" {
  value = azurerm_resource_group.appgw.name
}
output "public_ip_address" {
  value = try(azurerm_public_ip.appgw[0].ip_address, null)
}
output "private_ip_address" {
  value = local.private_ip
}
output "identity" {
  value = local.identity
}
output "waf_policy_ids" {
  value = { for name, policy in azurerm_web_application_firewall_policy.policies : name => policy.id }
}
output "backend_fqdns" {
  value = { for name, record in var.backend_dns_records : name => "${name}.${var.backend_dns_zone}" }
}
output "backend_targets" {
  value = { for name, record in var.backend_dns_records : name => record.ip_addresses }
}
output "backend_dns_zone_id" {
  value = try(azurerm_private_dns_zone.backend[0].id, null)
}
