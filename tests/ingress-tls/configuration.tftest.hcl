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
run "reencrypted_ingress_backends" {
  command = apply
  assert {
    condition = length(azurerm_application_gateway.appgw.backend_http_settings) == 3 && alltrue([
      for settings in azurerm_application_gateway.appgw.backend_http_settings : settings.port == 443 && settings.protocol == "Https"
    ])
    error_message = "Every listener/path/preview backend in the ingress profile must use HTTPS443."
  }
  assert {
    condition     = alltrue([for probe in azurerm_application_gateway.appgw.probe : probe.protocol == "Https" && probe.path == "/healthz"])
    error_message = "HTTPS ingress health probes must validate the actual backend protocol and application endpoint."
  }
  assert {
    condition     = output.backend_targets.service == tolist(["10.81.4.21"]) && output.backend_fqdns.service == "service.apps.internal.example" && one([for settings in azurerm_application_gateway.appgw.backend_http_settings : settings.host_name if settings.name == "preview"]) == "web.example.test"
    error_message = "Explicit cutover must select the verified candidate while preserving the alias and Host/SNI."
  }
}
