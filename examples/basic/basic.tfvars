tenant_id = "00000000-0000-0000-0000-000000000001"
# Standalone minimal public TLS/WAF example; existing network, certificate and backend required.
location             = "uksouth"
location_abbreviated = "uks"
environment          = "dev"
subscription         = "pprd"
subscription_id_map = {
  hub  = "00000000-0000-0000-0000-000000000002"
  pprd = "00000000-0000-0000-0000-000000000003"
  prd  = "00000000-0000-0000-0000-000000000004"
}
network = {
  subnet_id          = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/uks-pprd-vnet-rg-01/providers/Microsoft.Network/virtualNetworks/uks-pprd-vnet-01/subnets/uks-pprd-appgateway"
  subnet_cidr        = "10.81.8.0/24"
  virtual_network_id = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/uks-pprd-vnet-rg-01/providers/Microsoft.Network/virtualNetworks/uks-pprd-vnet-01"
}
certificate_subscription = "pprd"
key_vault_id             = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/example-certificates-rg/providers/Microsoft.KeyVault/vaults/example-certificates"
certificates             = { example = { key_vault_secret_id = "https://example-certificates.vault.azure.net/secrets/example-tls/" } }
private_frontend         = { enabled = false }
backend_pools            = { service = { ip_addresses = ["10.81.0.20"] } }
backend_settings         = { web = { port = 80, host_name = "web.example.test", probe = { path = "/healthz" } } }
listeners = {
  web      = { host_name = "web.example.test", certificate_name = "example", priority = 100, backend_pool = "service", backend_settings = "web" }
  redirect = { host_name = "web.example.test", protocol = "Http", priority = 110, redirect_to = "web" }
}
