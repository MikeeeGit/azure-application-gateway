locals {
  # This is the same immutable-per-plan manifest used by the shared helpers.
  delivery                    = jsondecode(file("${path.root}/delivery.azure.json"))
  delivery_subscription_alias = try(local.delivery.environments[var.environment].subscription_alias, var.subscription)
}
resource "terraform_data" "delivery_contract" {
  lifecycle {
    precondition {
      condition = try(
        lower(var.tenant_id) == lower(local.delivery.tenant_id) &&
        { for alias, id in var.subscription_id_map : alias => lower(id) } == { for alias, id in local.delivery.subscriptions : alias => lower(id) },
        false
      )
      error_message = "tenant_id and the complete subscription_id_map must match delivery.azure.json."
    }
    precondition {
      condition = try(
        local.delivery.environments[var.environment].subscription_alias == var.subscription &&
        contains(local.delivery.regions, var.location_abbreviated), false
      )
      error_message = "Environment subscription alias and region must match delivery.azure.json."
    }
  }
}
