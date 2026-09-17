locals {
  waf_config_root = coalesce(var.waf_config_root, "${path.root}/config/all/waf-policy")
  waf_data = {
    for name, policy in var.waf_policies : name => {
      overrides  = jsondecode(policy.files.rule_group_overrides == null ? jsonencode(policy.rule_group_overrides) : try(jsonencode(jsondecode(file("${local.waf_config_root}/${policy.files.rule_group_overrides}"))), "{}"))
      exclusions = jsondecode(policy.files.managed_rule_exclusions == null ? jsonencode(policy.managed_rule_exclusions) : try(jsonencode(jsondecode(file("${local.waf_config_root}/${policy.files.managed_rule_exclusions}"))), "[]"))
      custom     = jsondecode(policy.files.custom_rules == null ? jsonencode(policy.custom_rules) : try(jsonencode(jsondecode(file("${local.waf_config_root}/${policy.files.custom_rules}"))), "[]"))
      files_valid = alltrue([
        for filename in [policy.files.rule_group_overrides, policy.files.managed_rule_exclusions, policy.files.custom_rules] :
        filename == null ? true : can(jsondecode(file("${local.waf_config_root}/${filename}")))
      ])
    }
  }
}
resource "azurerm_web_application_firewall_policy" "policies" {
  for_each            = var.waf_policies
  name                = "${local.label}-appgateway-${each.key}-waf"
  resource_group_name = azurerm_resource_group.appgw.name
  location            = var.location
  tags                = local.tags
  policy_settings {
    enabled                          = each.value.enabled
    mode                             = each.value.mode
    request_body_check               = each.value.request_body_check
    request_body_enforcement         = each.value.request_body_enforcement
    max_request_body_size_in_kb      = each.value.max_request_body_size_kb
    request_body_inspect_limit_in_kb = each.value.request_body_inspect_limit_kb
    file_upload_limit_in_mb          = each.value.file_upload_limit_mb
  }
  dynamic "custom_rules" {
    for_each = local.waf_data[each.key].custom
    content {
      name                 = custom_rules.value.name
      priority             = custom_rules.value.priority
      enabled              = try(custom_rules.value.enabled, true)
      rule_type            = try(custom_rules.value.rule_type, "MatchRule")
      action               = custom_rules.value.action
      rate_limit_duration  = try(custom_rules.value.rate_limit_duration, null)
      rate_limit_threshold = try(custom_rules.value.rate_limit_threshold, null)
      group_rate_limit_by  = try(custom_rules.value.group_rate_limit_by, null)
      dynamic "match_conditions" {
        for_each = custom_rules.value.match_conditions
        content {
          operator           = match_conditions.value.operator
          negation_condition = try(match_conditions.value.negation_condition, false)
          match_values       = try(match_conditions.value.match_values, [])
          transforms         = try(match_conditions.value.transforms, [])
          dynamic "match_variables" {
            for_each = match_conditions.value.match_variables
            content {
              variable_name = match_variables.value.variable_name
              selector      = try(match_variables.value.selector, null)
            }
          }
        }
      }
    }
  }
  managed_rules {
    managed_rule_set {
      type    = "Microsoft_DefaultRuleSet"
      version = "2.1"
      dynamic "rule_group_override" {
        for_each = local.waf_data[each.key].overrides
        content {
          rule_group_name = rule_group_override.key
          dynamic "rule" {
            for_each = rule_group_override.value
            content {
              id      = rule.value
              enabled = false
              action  = "AnomalyScoring"
            }
          }
        }
      }
    }
    managed_rule_set {
      type    = "Microsoft_BotManagerRuleSet"
      version = "1.0"
    }
    dynamic "exclusion" {
      for_each = local.waf_data[each.key].exclusions
      content {
        match_variable          = exclusion.value.match_variable
        selector                = exclusion.value.selector
        selector_match_operator = exclusion.value.selector_match_operator
        dynamic "excluded_rule_set" {
          for_each = try(exclusion.value.excluded_rule_sets, [])
          content {
            type    = excluded_rule_set.value.type
            version = excluded_rule_set.value.version
            dynamic "rule_group" {
              for_each = excluded_rule_set.value.rule_groups
              content {
                rule_group_name = rule_group.value.rule_group_name
                excluded_rules  = rule_group.value.excluded_rules
              }
            }
          }
        }
      }
    }
  }
  lifecycle {
    precondition {
      condition     = local.waf_data[each.key].files_valid
      error_message = "WAF JSON files must exist beneath waf_config_root and contain valid JSON; empty files are not valid policy data."
    }
    precondition {
      condition = try(
        length(distinct([for rule in local.waf_data[each.key].custom : rule.priority])) == length(local.waf_data[each.key].custom) &&
        length(distinct([for rule in local.waf_data[each.key].custom : rule.name])) == length(local.waf_data[each.key].custom) &&
        alltrue([for rule in local.waf_data[each.key].custom :
          rule.priority >= 1 && rule.priority <= 100 && floor(rule.priority) == rule.priority &&
          contains(["Allow", "Block", "Log", "JSChallenge"], rule.action) &&
          contains(["MatchRule", "RateLimitRule"], try(rule.rule_type, "MatchRule")) &&
          (try(rule.rule_type, "MatchRule") != "RateLimitRule" ? true : (
            rule.action != "Allow" &&
            contains(["OneMin", "FiveMins"], try(rule.rate_limit_duration, "")) &&
            try(rule.rate_limit_threshold >= 1, false)
          )) &&
          length(rule.match_conditions) > 0 &&
          alltrue([for condition in rule.match_conditions :
            length(condition.match_variables) > 0 &&
            contains(["Any", "IPMatch", "GeoMatch", "Equal", "Contains", "LessThan", "GreaterThan", "LessThanOrEqual", "GreaterThanOrEqual", "BeginsWith", "EndsWith", "Regex"], condition.operator) &&
            (condition.operator == "Any" || try(length(condition.match_values) > 0, false))
          ])
        ]), false
      )
      error_message = "Custom WAF rules need unique names/priorities 1..100, valid action/type/matches; rate-limit rules need duration/threshold and cannot Allow."
    }
  }
}
