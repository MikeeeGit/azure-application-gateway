provider "azurerm" {
  subscription_id                 = local.delivery.subscriptions[local.delivery_subscription_alias]
  tenant_id                       = local.delivery.tenant_id
  resource_provider_registrations = "none"
  features {}
}

# Certificate vault permissions can belong to a different subscription.
provider "azurerm" {
  alias                           = "certificates"
  subscription_id                 = local.delivery.subscriptions[coalesce(var.certificate_subscription, local.delivery_subscription_alias)]
  tenant_id                       = local.delivery.tenant_id
  resource_provider_registrations = "none"
  features {}
}
