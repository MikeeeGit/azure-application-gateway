tenant_id = "00000000-0000-0000-0000-000000000001"
# Synthetic public examples; replace BOTH these IDs and delivery.azure.json in your private copy.
subscription_id_map = {
  hub  = "00000000-0000-0000-0000-000000000002"
  pprd = "00000000-0000-0000-0000-000000000003"
  prd  = "00000000-0000-0000-0000-000000000004"
}
global_tags = {
  Owner     = "platform-team@example.com"
  ManagedBy = "Terraform"
  Service   = "application-gateway"
}
certificate_subscription = "hub"
key_vault_id             = "/subscriptions/00000000-0000-0000-0000-000000000002/resourceGroups/uks-hub-certificates-rg/providers/Microsoft.KeyVault/vaults/example-certificates"
certificate_access_mode  = "rbac"
certificates = {
  example = { key_vault_secret_id = "https://example-certificates.vault.azure.net/secrets/example-tls/" }
}
waf_policies = {
  global = {
    files = {
      custom_rules            = "sample-custom-rules.json"
      rule_group_overrides    = "sample-rule-overrides.json"
      managed_rule_exclusions = "sample-exclusions.json"
    }
  }
  api = {}
}
diag_log_workspace = null

# Full scenario: network foundation and two independently managed AKS clusters already exist.
# Deploy actual internal backend Services first; the platform demo creates them through shared Kustomize delivery.
location             = "uksouth"
location_abbreviated = "uks"
environment          = "pprd"
subscription         = "pprd"
environment_tags     = { Environment = "pprd" }
availability_zones   = ["1", "2", "3"]
network = {
  subnet_id          = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/uks-pprd-vnet-rg-01/providers/Microsoft.Network/virtualNetworks/uks-pprd-vnet-01/subnets/uks-pprd-appgateway"
  subnet_cidr        = "10.81.8.0/24"
  virtual_network_id = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/uks-pprd-vnet-rg-01/providers/Microsoft.Network/virtualNetworks/uks-pprd-vnet-01"
}
# This CHILD zone is owned by this stack; the parent internal.example belongs to network foundation.
backend_dns_zone = "apps.internal.example"
backend_dns_link_virtual_network_ids = {
  # Required when the spoke queries a DNS proxy/resolver in the hub.
  hub = "/subscriptions/00000000-0000-0000-0000-000000000002/resourceGroups/uks-hub-vnet-rg-01/providers/Microsoft.Network/virtualNetworks/uks-hub-vnet-01"
}
backend_dns_records = {
  # Change this one target to the separately verified aks02 backend IP during cutover.
  service = { ip_addresses = ["10.81.0.20"], ttl = 30 }
}
backend_pools = {
  service = { dns_record = "service" }
  preview = { ip_addresses = ["10.81.4.20"] }
}
backend_settings = {
  web     = { port = 80, connection_draining = { enabled = true, timeout = 300 }, host_name = "web.example.test", probe = { host = "web.example.test", path = "/healthz" } }
  api     = { port = 80, connection_draining = { enabled = true, timeout = 300 }, host_name = "api.example.test", probe = { host = "api.example.test", path = "/healthz" } }
  preview = { port = 80, connection_draining = { enabled = true, timeout = 300 }, host_name = "web.example.test", probe = { host = "web.example.test", path = "/healthz" } }
}
listeners = {
  web = {
    host_name    = "web.example.test", certificate_name = "example", priority = 100
    backend_pool = "service", backend_settings = "web", rewrite_rule_set = "security"
    paths = [{
      name = "api", paths = ["/api/*"], backend_pool = "service", backend_settings = "api", waf_policy = "api"
    }]
  }
  web_redirect = { host_name = "web.example.test", protocol = "Http", priority = 110, redirect_to = "web" }
  api = {
    host_name    = "api.example.test", certificate_name = "example", priority = 120
    backend_pool = "service", backend_settings = "api", waf_policy = "api"
  }
  preview = {
    host_name    = "preview.example.test", certificate_name = "example", priority = 130
    backend_pool = "preview", backend_settings = "preview"
  }
  private = {
    host_name    = "private.example.test", frontend = "private", certificate_name = "example", priority = 140
    backend_pool = "service", backend_settings = "web"
  }
}
rewrite_rule_sets = {
  security = [{
    name             = "nosniff", rule_sequence = 100
    response_headers = { X-Content-Type-Options = "nosniff" }
  }]
}
