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
run "candidate_preview_preserves_active_backend" {
  command = apply
  assert {
    condition     = output.backend_targets.service == tolist(["10.81.0.20"]) && one([for setting in azurerm_application_gateway.appgw.backend_http_settings : setting.protocol if setting.name == "web"]) == "Http" && one([for setting in azurerm_application_gateway.appgw.backend_http_settings : setting.port if setting.name == "api"]) == 80
    error_message = "Candidate installation must not switch the live DNS alias or change active HTTP backend protocol."
  }
  assert {
    condition     = one([for pool in azurerm_application_gateway.appgw.backend_address_pool : pool.ip_addresses if pool.name == "preview"]) == toset(["10.81.4.21"]) && one([for setting in azurerm_application_gateway.appgw.backend_http_settings : setting.protocol if setting.name == "preview"]) == "Https" && one([for setting in azurerm_application_gateway.appgw.backend_http_settings : setting.port if setting.name == "preview"]) == 443
    error_message = "Only the preview path should reach the distinct candidate controller over HTTPS443."
  }
}
