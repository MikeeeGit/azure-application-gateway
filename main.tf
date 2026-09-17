data "terraform_remote_state" "network" {
  count   = var.network_state == null ? 0 : 1
  backend = "azurerm"
  config = var.network_state == null ? {} : {
    subscription_id      = var.network_state.subscription_id
    resource_group_name  = var.network_state.resource_group_name
    storage_account_name = var.network_state.storage_account_name
    container_name       = var.network_state.container_name
    key                  = var.network_state.key
    use_azuread_auth     = true
  }
}

locals {
  label = "${var.location_abbreviated}-${var.environment}"
  tags  = merge(var.global_tags, var.environment_tags)
  network = var.network_state == null ? var.network : {
    subnet_id          = data.terraform_remote_state.network[0].outputs.subnet_ids[var.network_state.subnet_key]
    subnet_cidr        = data.terraform_remote_state.network[0].outputs.subnet_address_prefixes[var.network_state.subnet_key]
    virtual_network_id = split("/subnets/", data.terraform_remote_state.network[0].outputs.subnet_ids[var.network_state.subnet_key])[0]
  }
  private_ip = var.private_frontend.enabled ? coalesce(var.private_frontend.ip_address, try(cidrhost(local.network.subnet_cidr, 7), "invalid")) : null
  identity = var.existing_identity != null ? var.existing_identity : {
    id           = azurerm_user_assigned_identity.appgw[0].id
    principal_id = azurerm_user_assigned_identity.appgw[0].principal_id
    tenant_id    = azurerm_user_assigned_identity.appgw[0].tenant_id
  }
  dns_links = var.backend_dns_zone == null ? {} : merge(var.backend_dns_link_virtual_network_ids, {
    gateway = local.network.virtual_network_id
  })
}

resource "azurerm_resource_group" "appgw" {
  name     = coalesce(var.resource_group_name, "${local.label}-appgateway-rg")
  location = var.location
  tags     = local.tags
}

resource "azurerm_user_assigned_identity" "appgw" {
  count               = var.existing_identity == null ? 1 : 0
  name                = "${local.label}-appgateway-identity"
  resource_group_name = azurerm_resource_group.appgw.name
  location            = var.location
  tags                = local.tags
}

resource "azurerm_role_assignment" "certificate_reader" {
  count                            = length(var.certificates) > 0 && var.certificate_access_mode == "rbac" ? 1 : 0
  provider                         = azurerm.certificates
  scope                            = var.key_vault_id
  role_definition_name             = "Key Vault Secrets User"
  principal_id                     = local.identity.principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

resource "azurerm_key_vault_access_policy" "certificate_reader" {
  count              = length(var.certificates) > 0 && var.certificate_access_mode == "access_policy" ? 1 : 0
  provider           = azurerm.certificates
  key_vault_id       = var.key_vault_id
  tenant_id          = local.identity.tenant_id
  object_id          = local.identity.principal_id
  secret_permissions = ["Get"]
}

resource "azurerm_public_ip" "appgw" {
  count               = var.public_frontend_enabled ? 1 : 0
  name                = "${local.label}-appgateway-pip"
  resource_group_name = azurerm_resource_group.appgw.name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.availability_zones
  tags                = local.tags
}

resource "azurerm_application_gateway" "appgw" {
  name                = coalesce(var.gateway_name, "${local.label}-appgateway")
  resource_group_name = azurerm_resource_group.appgw.name
  location            = var.location
  zones               = var.availability_zones
  tags                = local.tags
  firewall_policy_id  = azurerm_web_application_firewall_policy.policies[var.global_waf_policy].id

  sku {
    name = "WAF_v2"
    tier = "WAF_v2"
  }
  autoscale_configuration {
    min_capacity = var.autoscale.min_capacity
    max_capacity = var.autoscale.max_capacity
  }
  identity {
    type         = "UserAssigned"
    identity_ids = [local.identity.id]
  }
  ssl_policy {
    policy_type = "Predefined"
    policy_name = var.ssl_policy_name
  }
  gateway_ip_configuration {
    name      = "gateway"
    subnet_id = local.network.subnet_id
  }
  frontend_port {
    name = "http"
    port = 80
  }
  frontend_port {
    name = "https"
    port = 443
  }
  dynamic "frontend_ip_configuration" {
    for_each = var.public_frontend_enabled ? [1] : []
    content {
      name                 = "public"
      public_ip_address_id = azurerm_public_ip.appgw[0].id
    }
  }
  dynamic "frontend_ip_configuration" {
    for_each = var.private_frontend.enabled ? [1] : []
    content {
      name                          = "private"
      subnet_id                     = local.network.subnet_id
      private_ip_address_allocation = "Static"
      private_ip_address            = local.private_ip
    }
  }
  dynamic "backend_address_pool" {
    for_each = var.backend_pools
    content {
      name         = backend_address_pool.key
      ip_addresses = backend_address_pool.value.ip_addresses
      fqdns = backend_address_pool.value.dns_record != null ? [
        "${backend_address_pool.value.dns_record}.${var.backend_dns_zone}"
      ] : backend_address_pool.value.fqdns
    }
  }
  dynamic "backend_http_settings" {
    for_each = var.backend_settings
    content {
      name                  = backend_http_settings.key
      port                  = backend_http_settings.value.port
      protocol              = backend_http_settings.value.protocol
      host_name             = backend_http_settings.value.host_name
      cookie_based_affinity = backend_http_settings.value.cookie_based_affinity ? "Enabled" : "Disabled"
      request_timeout       = backend_http_settings.value.request_timeout
      probe_name            = backend_http_settings.value.probe == null ? null : backend_http_settings.key
      dynamic "connection_draining" {
        for_each = backend_http_settings.value.connection_draining == null ? [] : [backend_http_settings.value.connection_draining]
        content {
          enabled           = connection_draining.value.enabled
          drain_timeout_sec = connection_draining.value.timeout
        }
      }
    }
  }
  dynamic "probe" {
    for_each = { for name, settings in var.backend_settings : name => settings if settings.probe != null }
    content {
      name                = probe.key
      protocol            = probe.value.protocol
      host                = coalesce(probe.value.probe.host, probe.value.host_name)
      path                = probe.value.probe.path
      interval            = probe.value.probe.interval
      timeout             = probe.value.probe.timeout
      unhealthy_threshold = probe.value.probe.unhealthy_threshold
      match {
        status_code = probe.value.probe.status_codes
      }
    }
  }
  dynamic "ssl_certificate" {
    for_each = var.certificates
    content {
      name                = ssl_certificate.key
      key_vault_secret_id = ssl_certificate.value.key_vault_secret_id
    }
  }
  dynamic "http_listener" {
    for_each = var.listeners
    content {
      name                           = http_listener.key
      host_name                      = http_listener.value.host_name
      frontend_ip_configuration_name = http_listener.value.frontend
      frontend_port_name             = http_listener.value.protocol == "Https" ? "https" : "http"
      protocol                       = http_listener.value.protocol
      ssl_certificate_name           = http_listener.value.certificate_name
      require_sni                    = http_listener.value.protocol == "Https" ? true : null
      firewall_policy_id             = http_listener.value.waf_policy == null ? null : azurerm_web_application_firewall_policy.policies[http_listener.value.waf_policy].id
    }
  }
  dynamic "redirect_configuration" {
    for_each = { for name, listener in var.listeners : name => listener if listener.redirect_to != null }
    content {
      name                 = redirect_configuration.key
      redirect_type        = "Permanent"
      target_listener_name = redirect_configuration.value.redirect_to
      include_path         = true
      include_query_string = true
    }
  }
  dynamic "request_routing_rule" {
    for_each = var.listeners
    content {
      name                        = request_routing_rule.key
      priority                    = request_routing_rule.value.priority
      http_listener_name          = request_routing_rule.key
      rule_type                   = length(request_routing_rule.value.paths) > 0 ? "PathBasedRouting" : "Basic"
      url_path_map_name           = length(request_routing_rule.value.paths) > 0 ? request_routing_rule.key : null
      backend_address_pool_name   = length(request_routing_rule.value.paths) > 0 ? null : request_routing_rule.value.backend_pool
      backend_http_settings_name  = length(request_routing_rule.value.paths) > 0 ? null : request_routing_rule.value.backend_settings
      redirect_configuration_name = request_routing_rule.value.redirect_to == null ? null : request_routing_rule.key
      rewrite_rule_set_name       = length(request_routing_rule.value.paths) > 0 || request_routing_rule.value.redirect_to != null ? null : request_routing_rule.value.rewrite_rule_set
    }
  }
  dynamic "url_path_map" {
    for_each = { for name, listener in var.listeners : name => listener if length(listener.paths) > 0 }
    content {
      name                               = url_path_map.key
      default_backend_address_pool_name  = url_path_map.value.backend_pool
      default_backend_http_settings_name = url_path_map.value.backend_settings
      default_rewrite_rule_set_name      = url_path_map.value.rewrite_rule_set
      dynamic "path_rule" {
        for_each = url_path_map.value.paths
        content {
          name                       = path_rule.value.name
          paths                      = path_rule.value.paths
          backend_address_pool_name  = path_rule.value.backend_pool
          backend_http_settings_name = path_rule.value.backend_settings
          firewall_policy_id         = path_rule.value.waf_policy == null ? null : azurerm_web_application_firewall_policy.policies[path_rule.value.waf_policy].id
          rewrite_rule_set_name      = path_rule.value.rewrite_rule_set
        }
      }
    }
  }
  dynamic "rewrite_rule_set" {
    for_each = var.rewrite_rule_sets
    content {
      name = rewrite_rule_set.key
      dynamic "rewrite_rule" {
        for_each = rewrite_rule_set.value
        content {
          name          = rewrite_rule.value.name
          rule_sequence = rewrite_rule.value.rule_sequence
          dynamic "request_header_configuration" {
            for_each = rewrite_rule.value.request_headers
            content {
              header_name  = request_header_configuration.key
              header_value = request_header_configuration.value
            }
          }
          dynamic "response_header_configuration" {
            for_each = rewrite_rule.value.response_headers
            content {
              header_name  = response_header_configuration.key
              header_value = response_header_configuration.value
            }
          }
          dynamic "url" {
            for_each = rewrite_rule.value.url == null ? [] : [rewrite_rule.value.url]
            content {
              path         = url.value.path
              query_string = url.value.query_string
              reroute      = url.value.reroute
            }
          }
        }
      }
    }
  }
  lifecycle {
    precondition {
      condition = var.certificate_access_mode == "existing" || length(var.certificates) == 0 ? true : alltrue([
        for cert in values(var.certificates) :
        try(lower(split(".", split("/", cert.key_vault_secret_id)[2])[0]) == lower(element(reverse(split("/", var.key_vault_id)), 0)), false)
      ])
      error_message = "Certificates must use the vault receiving the managed permission. For permissions managed across multiple vaults, select existing mode."
    }
    precondition {
      condition     = var.private_frontend.enabled ? try(cidrhost("${local.private_ip}/${split("/", local.network.subnet_cidr)[1]}", 0) == cidrhost(local.network.subnet_cidr, 0) && !contains([cidrhost(local.network.subnet_cidr, 0), cidrhost(local.network.subnet_cidr, 1), cidrhost(local.network.subnet_cidr, 2), cidrhost(local.network.subnet_cidr, 3), cidrhost(local.network.subnet_cidr, -1)], local.private_ip), false) : true
      error_message = "The private frontend IP must be inside the dedicated Application Gateway subnet."
    }
  }
  # Ordering avoids requesting the certificate before the identity grant exists.
  # Azure RBAC propagation remains eventually consistent; see deployment.md.
  depends_on = [
    terraform_data.delivery_contract,
    azurerm_role_assignment.certificate_reader,
    azurerm_key_vault_access_policy.certificate_reader,
    azurerm_private_dns_a_record.backend,
    azurerm_private_dns_zone_virtual_network_link.backend,
    azurerm_private_dns_zone_virtual_network_link.key_vault
  ]
}
