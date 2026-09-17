mock_provider "azurerm" {
  mock_resource "azurerm_web_application_firewall_policy" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/uks-pprd-appgateway-rg/providers/Microsoft.Network/applicationGatewayWebApplicationFirewallPolicies/mock-policy"
    }
  }
  mock_resource "azurerm_user_assigned_identity" {
    defaults = {
      id           = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/uks-pprd-appgateway-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/mock-identity"
      principal_id = "00000000-0000-0000-0000-000000000010"
      tenant_id    = "00000000-0000-0000-0000-000000000001"
    }
  }
  mock_resource "azurerm_public_ip" {
    defaults = {
      id         = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/uks-pprd-appgateway-rg/providers/Microsoft.Network/publicIPAddresses/mock-pip"
      ip_address = "192.0.2.10"
    }
  }
}
mock_provider "azurerm" {
  alias = "certificates"
}
run "fresh_https_keeps_preview_independent" {
  command = apply
  assert {
    condition = length(azurerm_application_gateway.appgw.backend_http_settings) == 3 && alltrue([
      for settings in azurerm_application_gateway.appgw.backend_http_settings : settings.port == 443 && settings.protocol == "Https"
    ])
    error_message = "Every fresh-install backend must use HTTPS443; no legacy HTTP path should remain."
  }
  assert {
    condition     = output.backend_targets.service == tolist(["10.81.0.21"]) && output.backend_fqdns.service == "service.apps.internal.example" && one([for pool in azurerm_application_gateway.appgw.backend_address_pool : pool.ip_addresses if pool.name == "preview"]) == toset(["10.81.4.21"])
    error_message = "Fresh live traffic must use aks01 while preview independently targets aks02 at the allocated Envoy addresses."
  }
  assert {
    condition     = alltrue([for probe in azurerm_application_gateway.appgw.probe : probe.protocol == "Https" && probe.path == "/healthz"]) && one([for settings in azurerm_application_gateway.appgw.backend_http_settings : settings.host_name if settings.name == "web"]) == "web.example.test" && one([for settings in azurerm_application_gateway.appgw.backend_http_settings : settings.host_name if settings.name == "api"]) == "api.example.test" && one([for settings in azurerm_application_gateway.appgw.backend_http_settings : settings.host_name if settings.name == "preview"]) == "web.example.test"
    error_message = "Fresh-install probes and Host/SNI contracts must match the existing web/API/preview application routes."
  }
}
