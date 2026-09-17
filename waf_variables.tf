variable "global_waf_policy" {
  type        = string
  default     = "global"
  description = "Default gateway WAF policy key. Listener/path policies override, rather than merge with, it."
  validation {
    condition     = contains(keys(var.waf_policies), var.global_waf_policy)
    error_message = "global_waf_policy must be present in waf_policies."
  }
}
variable "waf_config_root" {
  type        = string
  default     = null
  description = "JSON policy directory; null uses path.root/config/all/waf-policy."
}
variable "waf_policies" {
  description = "Application Gateway policies. DRS2.1 and BotManager1.0 are explicit compatibility choices. Inline rules or corresponding JSON files are supported."
  type = map(object({
    enabled                       = optional(bool, true)
    mode                          = optional(string, "Prevention")
    request_body_check            = optional(bool, true)
    max_request_body_size_kb      = optional(number, 128)
    request_body_inspect_limit_kb = optional(number, 128)
    file_upload_limit_mb          = optional(number, 100)
    rule_group_overrides          = optional(map(list(string)), {})
    managed_rule_exclusions = optional(list(object({
      match_variable          = string
      selector                = string
      selector_match_operator = string
      excluded_rule_sets = optional(list(object({
        type    = string
        version = string
        rule_groups = list(object({
          rule_group_name = string
          excluded_rules  = list(string)
        }))
      })), [])
    })), [])
    custom_rules = optional(list(object({
      name                 = string
      priority             = number
      enabled              = optional(bool, true)
      rule_type            = optional(string, "MatchRule")
      action               = string
      rate_limit_duration  = optional(string)
      rate_limit_threshold = optional(number)
      group_rate_limit_by  = optional(string)
      match_conditions = list(object({
        match_variables = list(object({
          variable_name = string
          selector      = optional(string)
        }))
        operator           = string
        negation_condition = optional(bool, false)
        match_values       = optional(list(string), [])
        transforms         = optional(list(string), [])
      }))
    })), [])
    files = optional(object({
      rule_group_overrides    = optional(string)
      managed_rule_exclusions = optional(string)
      custom_rules            = optional(string)
    }), {})
  }))
  default = { global = {} }
  validation {
    condition = length(var.waf_policies) > 0 && alltrue([
      for policy in values(var.waf_policies) :
      contains(["Detection", "Prevention"], policy.mode) &&
      policy.max_request_body_size_kb >= 8 && policy.max_request_body_size_kb <= 2000 &&
      policy.request_body_inspect_limit_kb >= 8 && policy.request_body_inspect_limit_kb <= 2000 &&
      policy.file_upload_limit_mb >= 1 && policy.file_upload_limit_mb <= 4000 &&
      (policy.files.rule_group_overrides == null || length(policy.rule_group_overrides) == 0) &&
      (policy.files.managed_rule_exclusions == null || length(policy.managed_rule_exclusions) == 0) &&
      (policy.files.custom_rules == null || length(policy.custom_rules) == 0)
    ])
    error_message = "Use valid WAF mode/body/upload limits and choose inline OR JSON data for each rule collection."
  }
}
