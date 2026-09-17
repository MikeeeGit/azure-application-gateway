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
