mock_provider "azurerm" {
  override_during = plan
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
  alias           = "certificates"
  override_during = plan
}
run "synthetic_configuration" {
  command = plan
  assert {
    condition     = one(azurerm_application_gateway.appgw.sku).name == "WAF_v2" && length(azurerm_application_gateway.appgw.http_listener) > 0
    error_message = "Each published configuration must create a WAF_v2 gateway with listeners."
  }
  assert {
    condition     = alltrue([for policy in azurerm_web_application_firewall_policy.policies : one(policy.policy_settings).enabled])
    error_message = "Published examples must keep WAF enabled."
  }
}
