variable "tenant_id" {
  type        = string
  description = "Deployment tenant UUID; must match delivery.azure.json."
  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.tenant_id))
    error_message = "tenant_id must be a UUID."
  }
}
variable "subscription_id_map" {
  description = "Explicit workload and optional certificate subscription aliases. Match delivery.azure.json."
  type        = map(string)
  validation {
    condition = length(var.subscription_id_map) > 0 && alltrue([
      for id in values(var.subscription_id_map) : can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", id))
    ])
    error_message = "Provide subscription aliases with UUID values."
  }
}
variable "subscription" {
  type        = string
  description = "Workload subscription alias."
  validation {
    condition     = contains(keys(var.subscription_id_map), var.subscription)
    error_message = "subscription must exist in subscription_id_map."
  }
}
variable "certificate_subscription" {
  type        = string
  description = "Vault subscription alias; null uses the workload subscription."
  default     = null
  validation {
    condition     = var.certificate_subscription == null ? true : contains(keys(var.subscription_id_map), var.certificate_subscription)
    error_message = "certificate_subscription must exist in subscription_id_map."
  }
}
variable "location" {
  type        = string
  description = "Azure region."
}
variable "location_abbreviated" {
  type        = string
  description = "Short region name used in generated names."
}
variable "environment" {
  type        = string
  description = "Environment label."
}
variable "resource_group_name" {
  type        = string
  default     = null
  description = "Optional name; defaults to <region>-<environment>-appgateway-rg."
}
variable "gateway_name" {
  type        = string
  default     = null
  description = "Optional name; defaults to <region>-<environment>-appgateway."
}
variable "global_tags" {
  type    = map(string)
  default = {}
}
variable "environment_tags" {
  type    = map(string)
  default = {}
}
variable "network" {
  description = "Existing dedicated Application Gateway subnet and its VNet. Set exactly one of network or network_state."
  type = object({
    subnet_id          = string
    subnet_cidr        = string
    virtual_network_id = string
  })
  default = null
  validation {
    condition     = (var.network != null) != (var.network_state != null)
    error_message = "Set exactly one of network or network_state."
  }
  validation {
    condition = var.network == null ? true : (
      can(cidrnetmask(var.network.subnet_cidr)) &&
      can(regex("(?i)^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft.Network/virtualNetworks/[^/]+/subnets/[^/]+$", var.network.subnet_id)) &&
      lower(try(split("/subnets/", var.network.subnet_id)[0], "")) == lower(var.network.virtual_network_id)
    )
    error_message = "network must contain a valid IPv4 CIDR and matching subnet/VNet resource IDs."
  }
}
variable "network_state" {
  description = "Optional explicit AzureAD-only network remote state. It must already exist; direct network IDs avoid granting whole-state read access."
  type = object({
    subscription_id      = string
    resource_group_name  = string
    storage_account_name = string
    container_name       = string
    key                  = string
    subnet_key           = optional(string, "appgateway")
  })
  default = null
}
variable "public_frontend_enabled" {
  type    = bool
  default = true
}
variable "private_frontend" {
  description = "Static private frontend. A null IP chooses host 7 of the dedicated subnet."
  type = object({
    enabled    = optional(bool, true)
    ip_address = optional(string)
  })
  default = {}
  validation {
    condition     = var.public_frontend_enabled || var.private_frontend.enabled
    error_message = "Enable at least one frontend."
  }
}
variable "availability_zones" {
  description = "Explicit region-supported zones; [] creates a non-zonal gateway. The public IP uses the same zones."
  type        = list(string)
  default     = []
  validation {
    condition = length(distinct(var.availability_zones)) == length(var.availability_zones) && alltrue([
      for zone in var.availability_zones : contains(["1", "2", "3"], zone)
    ])
    error_message = "availability_zones may contain unique values 1, 2 and 3."
  }
}
variable "autoscale" {
  type = object({
    min_capacity = optional(number, 2)
    max_capacity = optional(number, 10)
  })
  default = {}
  validation {
    condition     = var.autoscale.min_capacity >= 0 && var.autoscale.max_capacity >= 1 && var.autoscale.max_capacity <= 125 && var.autoscale.min_capacity <= var.autoscale.max_capacity && floor(var.autoscale.min_capacity) == var.autoscale.min_capacity && floor(var.autoscale.max_capacity) == var.autoscale.max_capacity
    error_message = "Use integer autoscale capacities with 0 <= min <= max <= 125 and max >= 1."
  }
}
variable "ssl_policy_name" {
  type        = string
  default     = "AppGwSslPolicy20220101S"
  description = "Explicit predefined frontend TLS policy; the default requires TLS 1.2 or newer."
  validation {
    condition     = contains(["AppGwSslPolicy20220101", "AppGwSslPolicy20220101S"], var.ssl_policy_name)
    error_message = "Choose a supported 2022 TLS policy; legacy TLS policies are intentionally excluded."
  }
}
variable "key_vault_id" {
  type        = string
  default     = null
  description = "Existing certificate vault ID. Required when this stack grants access."
  validation {
    condition = var.key_vault_id == null ? true : (
      can(regex("(?i)^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft.KeyVault/vaults/[A-Za-z0-9-]+$", var.key_vault_id)) &&
      try(lower(split("/", var.key_vault_id)[2]) == lower(var.subscription_id_map[coalesce(var.certificate_subscription, var.subscription)]), false)
    )
    error_message = "key_vault_id must belong to certificate_subscription (or the workload subscription when unset)."
  }
}
variable "certificate_access_mode" {
  type        = string
  default     = "rbac"
  description = "rbac grants Secrets User; access_policy grants Secret Get; existing leaves permissions to the vault owner."
  validation {
    condition     = contains(["rbac", "access_policy", "existing"], var.certificate_access_mode)
    error_message = "certificate_access_mode must be rbac, access_policy or existing."
  }
  validation {
    condition     = length(var.certificates) == 0 || var.certificate_access_mode == "existing" || var.key_vault_id != null
    error_message = "key_vault_id is required to manage certificate permissions."
  }
}
variable "existing_identity" {
  type = object({
    id           = string
    principal_id = string
    tenant_id    = string
  })
  default     = null
  description = "Existing user-assigned identity, or null to create one. Exactly one identity is attached."
}
variable "certificates" {
  description = "One unique certificate block per map key. Values are versionless Key Vault secret URIs, never PFX contents/passwords."
  type = map(object({
    key_vault_secret_id = string
  }))
  default = {}
  validation {
    condition = alltrue([
      for cert in values(var.certificates) : can(regex("^https://[A-Za-z0-9.-]+/secrets/[A-Za-z0-9-]+/?$", cert.key_vault_secret_id))
    ])
    error_message = "Certificate URIs must be HTTPS versionless /secrets/<name> URIs, without a version or query."
  }
}
variable "backend_pools" {
  type = map(object({
    ip_addresses = optional(list(string), [])
    fqdns        = optional(list(string), [])
    dns_record   = optional(string)
  }))
  description = "Choose IP addresses, supplied FQDNs, or an owned backend_dns_records key for each pool."
  validation {
    condition = length(var.backend_pools) > 0 && alltrue([
      for pool in values(var.backend_pools) :
      (length(pool.ip_addresses) > 0 ? 1 : 0) + (length(pool.fqdns) > 0 ? 1 : 0) + (pool.dns_record != null ? 1 : 0) == 1 &&
      alltrue([for ip in pool.ip_addresses : can(cidrnetmask("${ip}/32"))]) &&
      alltrue([for fqdn in pool.fqdns : can(regex("^[A-Za-z0-9][A-Za-z0-9.-]+[A-Za-z0-9]$", fqdn))])
    ])
    error_message = "Each backend pool needs exactly one nonempty IP, FQDN, or owned DNS-record source."
  }
  validation {
    condition = alltrue([
      for pool in values(var.backend_pools) : pool.dns_record == null ? true : var.backend_dns_zone != null && contains(keys(var.backend_dns_records), pool.dns_record)
    ])
    error_message = "Owned DNS pools require backend_dns_zone and a matching backend_dns_records key."
  }
}
variable "backend_settings" {
  type = map(object({
    port                  = number
    protocol              = optional(string, "Http")
    host_name             = optional(string)
    cookie_based_affinity = optional(bool, false)
    request_timeout       = optional(number, 300)
    connection_draining = optional(object({
      enabled = optional(bool, true)
      timeout = optional(number, 300)
    }))
    probe = optional(object({
      host                = optional(string)
      path                = optional(string, "/")
      interval            = optional(number, 30)
      timeout             = optional(number, 20)
      unhealthy_threshold = optional(number, 3)
      status_codes        = optional(list(string), ["200-399"])
    }))
  }))
  description = "Explicit backend protocol/port and optional probe. A probe requires its own host or backend host_name."
  validation {
    condition = length(var.backend_settings) > 0 && alltrue([
      for settings in values(var.backend_settings) :
      contains(["Http", "Https"], settings.protocol) && settings.port >= 1 && settings.port <= 65535 && floor(settings.port) == settings.port &&
      settings.request_timeout >= 1 && settings.request_timeout <= 86400 &&
      (settings.connection_draining == null ? true : settings.connection_draining.timeout >= 1 && settings.connection_draining.timeout <= 3600 && floor(settings.connection_draining.timeout) == settings.connection_draining.timeout) &&
      (settings.probe == null ? true : (
        (try(length(trimspace(settings.probe.host)) > 0, false) || try(length(trimspace(settings.host_name)) > 0, false)) &&
        startswith(settings.probe.path, "/") && settings.probe.timeout >= 1 && settings.probe.timeout < settings.probe.interval &&
        settings.probe.interval <= 86400 && settings.probe.unhealthy_threshold >= 1 && settings.probe.unhealthy_threshold <= 20 &&
        length(settings.probe.status_codes) > 0
      ))
    ])
    error_message = "Use valid backend protocol/port/timeout and probes with an explicit Host (or backend host_name), /path, timeout < interval and threshold 1..20."
  }
}
variable "listeners" {
  description = "Multi-host listeners, HTTP-to-HTTPS redirects and optional ordered path rules. Map keys are stable Azure child names."
  type = map(object({
    host_name        = string
    protocol         = optional(string, "Https")
    frontend         = optional(string, "public")
    certificate_name = optional(string)
    priority         = number
    backend_pool     = optional(string)
    backend_settings = optional(string)
    redirect_to      = optional(string)
    waf_policy       = optional(string)
    rewrite_rule_set = optional(string)
    paths = optional(list(object({
      name             = string
      paths            = list(string)
      backend_pool     = string
      backend_settings = string
      waf_policy       = optional(string)
      rewrite_rule_set = optional(string)
    })), [])
  }))
  validation {
    condition = length(var.listeners) > 0 && length(distinct([for item in values(var.listeners) : item.priority])) == length(var.listeners) && alltrue([
      for item in values(var.listeners) :
      contains(["Http", "Https"], item.protocol) && contains(["public", "private"], item.frontend) && length(trimspace(item.host_name)) > 0 &&
      item.priority >= 1 && item.priority <= 20000 && floor(item.priority) == item.priority &&
      (item.frontend == "public" ? var.public_frontend_enabled : var.private_frontend.enabled) &&
      (item.protocol == "Https" ? contains(keys(var.certificates), (item.certificate_name == null ? "" : item.certificate_name)) : item.certificate_name == null)
    ])
    error_message = "Listeners require valid protocols, enabled frontends, unique priorities 1..20000, and certificates for HTTPS only."
  }
  validation {
    condition = alltrue([
      for name, item in var.listeners : item.redirect_to != null ? (
        item.protocol == "Http" && item.redirect_to != name &&
        try(var.listeners[item.redirect_to].protocol == "Https", false) &&
        item.backend_pool == null && item.backend_settings == null && length(item.paths) == 0
        ) : (
        contains(keys(var.backend_pools), (item.backend_pool == null ? "" : item.backend_pool)) &&
        contains(keys(var.backend_settings), (item.backend_settings == null ? "" : item.backend_settings)) &&
        length(distinct([for path in item.paths : path.name])) == length(item.paths) &&
        alltrue([for path in item.paths :
          length(path.paths) > 0 && alltrue([for pattern in path.paths : startswith(pattern, "/")]) &&
          contains(keys(var.backend_pools), path.backend_pool) && contains(keys(var.backend_settings), path.backend_settings)
        ])
      )
    ])
    error_message = "Redirects must target an existing HTTPS listener and have no backend/path settings; forwarding routes and paths must reference existing pools/settings."
  }
  validation {
    condition = alltrue(flatten([
      for item in values(var.listeners) : [
        for entry in concat([{ waf_policy = item.waf_policy, rewrite_rule_set = item.rewrite_rule_set }], [for p in item.paths : { waf_policy = p.waf_policy, rewrite_rule_set = p.rewrite_rule_set }]) :
        (entry.waf_policy == null ? true : contains(keys(var.waf_policies), entry.waf_policy)) &&
        (entry.rewrite_rule_set == null ? true : contains(keys(var.rewrite_rule_sets), entry.rewrite_rule_set))
      ]
    ]))
    error_message = "Listener/path WAF and rewrite keys must exist."
  }
}
variable "rewrite_rule_sets" {
  type = map(list(object({
    name             = string
    rule_sequence    = number
    request_headers  = optional(map(string), {})
    response_headers = optional(map(string), {})
    url = optional(object({
      path         = optional(string)
      query_string = optional(string)
      reroute      = optional(bool, false)
    }))
  })))
  default     = {}
  description = "Optional request/response header and URL rewrites. No Front Door restriction or forwarded-header rewrite is added automatically."
}
variable "backend_dns_zone" {
  type        = string
  default     = null
  description = "Optional NEW private zone owned only by this state, for example apps.internal.example. Existing zones are not adopted implicitly."
  validation {
    condition     = var.backend_dns_zone == null ? true : can(regex("^[A-Za-z0-9][A-Za-z0-9.-]+[.][A-Za-z0-9-]+$", var.backend_dns_zone))
    error_message = "backend_dns_zone must be a DNS zone name."
  }
}
variable "backend_dns_records" {
  type = map(object({
    ip_addresses = list(string)
    ttl          = optional(number, 30)
  }))
  default = {}
  validation {
    condition = alltrue([
      for name, record in var.backend_dns_records :
      can(regex("^[A-Za-z0-9][A-Za-z0-9-]*$", name)) &&
      length(record.ip_addresses) > 0 && alltrue([for ip in record.ip_addresses : can(cidrnetmask("${ip}/32"))]) &&
      record.ttl >= 1 && record.ttl <= 2147483647
    ])
    error_message = "Backend DNS records need simple names, nonempty IPv4 lists, and a positive TTL."
  }
  validation {
    condition     = length(var.backend_dns_records) == 0 || var.backend_dns_zone != null
    error_message = "backend_dns_records requires an owned backend_dns_zone."
  }
}
variable "backend_dns_link_virtual_network_ids" {
  type        = map(string)
  default     = {}
  description = "Additional VNets linked to the owned backend zone. The gateway VNet is always linked automatically."
  validation {
    condition     = !contains(keys(var.backend_dns_link_virtual_network_ids), "gateway") && length(distinct(values(var.backend_dns_link_virtual_network_ids))) == length(var.backend_dns_link_virtual_network_ids)
    error_message = "DNS link keys must not use reserved gateway, and VNet IDs must be unique."
  }
}
variable "key_vault_private_dns_link" {
  type = object({
    zone_name           = optional(string, "privatelink.vaultcore.azure.net")
    resource_group_name = string
    link_name           = string
  })
  default     = null
  description = "Optional link from the gateway VNet to an EXISTING Key Vault private DNS zone in certificate_subscription. Omit when network foundation already owns this link."
}
variable "diag_log_workspace" {
  type        = string
  default     = null
  description = "Optional Log Analytics workspace resource ID."
}
