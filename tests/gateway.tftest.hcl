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
variables {
  tenant_id            = "00000000-0000-0000-0000-000000000001"
  location             = "uksouth"
  location_abbreviated = "uks"
  environment          = "pprd"
  subscription         = "pprd"
  subscription_id_map = {
    pprd = "00000000-0000-0000-0000-000000000003"
    hub  = "00000000-0000-0000-0000-000000000002"
    prd  = "00000000-0000-0000-0000-000000000004"
  }
  certificate_subscription = "hub"
  network = {
    subnet_id          = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/uks-pprd-vnet-rg-01/providers/Microsoft.Network/virtualNetworks/uks-pprd-vnet-01/subnets/uks-pprd-appgateway"
    subnet_cidr        = "10.81.8.0/24"
    virtual_network_id = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/uks-pprd-vnet-rg-01/providers/Microsoft.Network/virtualNetworks/uks-pprd-vnet-01"
  }
  key_vault_id = "/subscriptions/00000000-0000-0000-0000-000000000002/resourceGroups/uks-hub-certificates-rg/providers/Microsoft.KeyVault/vaults/example-certificates"
  certificates = {
    shared = { key_vault_secret_id = "https://example-certificates.vault.azure.net/secrets/example-tls/" }
  }
  backend_pools = {
    aks01 = { ip_addresses = ["10.81.0.20"] }
    aks02 = { ip_addresses = ["10.81.4.20"] }
  }
  backend_settings = {
    web = { port = 80, host_name = "web.example.test", probe = { path = "/healthz" } }
    api = { port = 8080, host_name = "api.internal.example", probe = { host = "probe.internal.example", path = "/ready" } }
  }
  listeners = {
    web      = { host_name = "web.example.test", certificate_name = "shared", priority = 100, backend_pool = "aks01", backend_settings = "web" }
    api      = { host_name = "api.example.test", certificate_name = "shared", priority = 110, backend_pool = "aks02", backend_settings = "api" }
    redirect = { host_name = "web.example.test", protocol = "Http", priority = 120, redirect_to = "web" }
  }
  global_tags      = { ManagedBy = "Terraform", Environment = "default" }
  environment_tags = { Environment = "pprd" }
}
run "tls_waf_dedup_probes_and_redirects" {
  command = plan
  assert {
    condition     = one(azurerm_application_gateway.appgw.sku).name == "WAF_v2" && length(azurerm_application_gateway.appgw.ssl_certificate) == 1
    error_message = "Shared TLS certificates must have a single block and WAF_v2 must stay enabled."
  }
  assert {
    condition     = one([for probe in azurerm_application_gateway.appgw.probe : probe.host if probe.name == "api"]) == "probe.internal.example" && one([for probe in azurerm_application_gateway.appgw.probe : probe.host if probe.name == "web"]) == "web.example.test"
    error_message = "Probe Host must use explicit probe host or backend host, not an unrelated listener host."
  }
  assert {
    condition     = one(azurerm_application_gateway.appgw.redirect_configuration).target_listener_name == "web" && output.private_ip_address == "10.81.8.7" && azurerm_application_gateway.appgw.tags.Environment == "pprd"
    error_message = "Redirect target, private subnet host allocation and tag precedence must be preserved."
  }
  assert {
    condition     = length(azurerm_role_assignment.certificate_reader) == 1 && azurerm_role_assignment.certificate_reader[0].role_definition_name == "Key Vault Secrets User" && length(azurerm_key_vault_access_policy.certificate_reader) == 0
    error_message = "RBAC must grant only certificate secret-read permissions."
  }
}
run "real_paths_and_policy_overrides" {
  command = plan
  variables {
    waf_policies = { global = {}, api = { mode = "Detection" } }
    rewrite_rule_sets = {
      security = [{ name = "nosniff", rule_sequence = 100, response_headers = { X-Content-Type-Options = "nosniff" } }]
    }
    listeners = {
      web = {
        host_name        = "web.example.test", certificate_name = "shared", priority = 100, backend_pool = "aks01", backend_settings = "web"
        rewrite_rule_set = "security"
        paths = [{
          name = "api", paths = ["/api/*"], backend_pool = "aks02", backend_settings = "api", waf_policy = "api", rewrite_rule_set = "security"
        }]
      }
    }
  }
  assert {
    condition     = one(azurerm_application_gateway.appgw.request_routing_rule).rule_type == "PathBasedRouting" && one(one(azurerm_application_gateway.appgw.url_path_map).path_rule).backend_address_pool_name == "aks02" && contains(one(one(azurerm_application_gateway.appgw.url_path_map).path_rule).paths, "/api/*")
    error_message = "Path input must create a real URL path map with the requested backend."
  }
}
run "dns_blue_backend" {
  command = plan
  variables {
    backend_dns_zone    = "apps.internal.example"
    backend_dns_records = { ingress = { ip_addresses = ["10.81.0.20"] } }
    backend_pools = {
      aks01 = { dns_record = "ingress" }
      aks02 = { fqdns = ["api.internal.example"] }
    }
  }
  assert {
    condition     = output.backend_fqdns.ingress == "ingress.apps.internal.example" && output.backend_targets.ingress == tolist(["10.81.0.20"]) && length(azurerm_private_dns_zone_virtual_network_link.backend) == 1
    error_message = "Owned backend aliases must resolve to supplied ingress IPs and link the gateway VNet."
  }
}
run "dns_green_backend_same_alias" {
  command = plan
  variables {
    backend_dns_zone    = "apps.internal.example"
    backend_dns_records = { ingress = { ip_addresses = ["10.81.4.20"] } }
  }
  assert {
    condition     = output.backend_fqdns.ingress == "ingress.apps.internal.example" && output.backend_targets.ingress == tolist(["10.81.4.20"])
    error_message = "Cutover changes DNS targets without changing the stable alias."
  }
}
run "private_frontend_and_existing_access" {
  command = plan
  variables {
    public_frontend_enabled = false
    certificate_access_mode = "existing"
    listeners = {
      private = { host_name = "web.example.test", frontend = "private", certificate_name = "shared", priority = 100, backend_pool = "aks01", backend_settings = "web" }
    }
  }
  assert {
    condition     = length(azurerm_public_ip.appgw) == 0 && one(azurerm_application_gateway.appgw.frontend_ip_configuration).name == "private" && length(azurerm_role_assignment.certificate_reader) == 0
    error_message = "Private listeners must not silently create a public IP or manage external permissions."
  }
}
run "legacy_access_policy_least_privilege" {
  command = plan
  variables { certificate_access_mode = "access_policy" }
  assert {
    condition     = length(azurerm_role_assignment.certificate_reader) == 0 && azurerm_key_vault_access_policy.certificate_reader[0].secret_permissions == tolist(["Get"])
    error_message = "Legacy access-policy mode needs only Secret Get."
  }
}
run "json_policy_files" {
  command = plan
  variables {
    waf_policies = {
      global = { files = { custom_rules = "sample-custom-rules.json", rule_group_overrides = "sample-rule-overrides.json", managed_rule_exclusions = "sample-exclusions.json" } }
    }
  }
  assert {
    condition     = length(azurerm_web_application_firewall_policy.policies["global"].custom_rules) == 1 && one(azurerm_web_application_firewall_policy.policies["global"].custom_rules).action == "Log"
    error_message = "First-class JSON policy files must reach the WAF resource."
  }
}
run "missing_json_fails_closed" {
  command = plan
  variables {
    waf_policies = { global = { files = { custom_rules = "missing.json" } } }
  }
  expect_failures = [azurerm_web_application_firewall_policy.policies]
}
run "empty_json_fails_closed" {
  command = plan
  variables {
    waf_config_root = "tests/fixtures"
    waf_policies    = { global = { files = { custom_rules = "empty.json" } } }
  }
  expect_failures = [azurerm_web_application_firewall_policy.policies]
}
run "duplicate_listener_priorities_rejected" {
  command = plan
  variables {
    listeners = {
      one = { host_name = "one.example.test", protocol = "Http", priority = 10, backend_pool = "aks01", backend_settings = "web" }
      two = { host_name = "two.example.test", protocol = "Http", priority = 10, backend_pool = "aks02", backend_settings = "api" }
    }
  }
  expect_failures = [var.listeners]
}
run "versioned_certificate_rejected" {
  command = plan
  variables {
    certificates = { shared = { key_vault_secret_id = "https://example-certificates.vault.azure.net/secrets/example-tls/012345" } }
  }
  expect_failures = [var.certificates]
}
run "outside_private_ip_rejected" {
  command = plan
  variables { private_frontend = { ip_address = "10.99.0.10" } }
  expect_failures = [azurerm_application_gateway.appgw]
}
run "reserved_private_ip_rejected" {
  command = plan
  variables { private_frontend = { ip_address = "10.81.8.1" } }
  expect_failures = [azurerm_application_gateway.appgw]
}
run "invalid_rate_limit_rejected" {
  command = plan
  variables {
    waf_policies = {
      global = { custom_rules = [{
        name             = "limit", priority = 10, rule_type = "RateLimitRule", action = "Allow", rate_limit_duration = "OneMin", rate_limit_threshold = 20
        match_conditions = [{ match_variables = [{ variable_name = "RemoteAddr" }], operator = "IPMatch", match_values = ["192.0.2.0/24"] }]
      }] }
    }
  }
  expect_failures = [azurerm_web_application_firewall_policy.policies]
}
run "network_remote_state_contract" {
  command = plan
  variables {
    network = null
    network_state = {
      subscription_id = "00000000-0000-0000-0000-000000000002", resource_group_name = "example-state-rg", storage_account_name = "examplenetworkstate", container_name = "tfstate", key = "network-pprd-uks.tfstate"
    }
  }
  override_data {
    target = data.terraform_remote_state.network[0]
    values = {
      outputs = {
        subnet_ids              = { appgateway = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/uks-pprd-vnet-rg-01/providers/Microsoft.Network/virtualNetworks/uks-pprd-vnet-01/subnets/uks-pprd-appgateway" }
        subnet_address_prefixes = { appgateway = "10.81.8.0/24" }
      }
    }
  }
  assert {
    condition     = output.private_ip_address == "10.81.8.7"
    error_message = "Remote network output contract must preserve logical appgateway subnet keys."
  }
}
run "delivery_subscription_mismatch_rejected" {
  command = plan
  variables { subscription = "prd" }
  expect_failures = [terraform_data.delivery_contract]
}
run "delivery_tenant_mismatch_rejected" {
  command = plan
  variables { tenant_id = "00000000-0000-0000-0000-000000000099" }
  expect_failures = [terraform_data.delivery_contract]
}
run "delivery_map_mismatch_rejected" {
  command = plan
  variables {
    subscription_id_map = {
      hub  = "00000000-0000-0000-0000-000000000002"
      pprd = "00000000-0000-0000-0000-000000000003"
      prd  = "00000000-0000-0000-0000-000000000099"
    }
  }
  expect_failures = [terraform_data.delivery_contract]
}
run "https_backend_sni_and_draining" {
  command = plan
  variables {
    backend_settings = {
      web = { port = 443, protocol = "Https", host_name = "web.example.test", probe = { path = "/ready" }, connection_draining = { enabled = true, timeout = 300 } }
      api = { port = 443, protocol = "Https", host_name = "api.example.test", probe = { path = "/ready" }, connection_draining = { enabled = true, timeout = 120 } }
    }
  }
  assert {
    condition     = alltrue([for listener in azurerm_application_gateway.appgw.http_listener : listener.protocol != "Https" || listener.require_sni]) && alltrue([for settings in azurerm_application_gateway.appgw.backend_http_settings : settings.protocol == "Https" && one(settings.connection_draining).enabled])
    error_message = "HTTPS listeners require SNI and backend HTTPS/draining configuration must be forwarded."
  }
}
