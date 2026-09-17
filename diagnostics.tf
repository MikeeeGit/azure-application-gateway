resource "azurerm_monitor_diagnostic_setting" "appgw" {
  count                      = var.diag_log_workspace == null ? 0 : 1
  name                       = "${local.label}-appgateway-diagnostics"
  target_resource_id         = azurerm_application_gateway.appgw.id
  log_analytics_workspace_id = var.diag_log_workspace
  enabled_log {
    category_group = "allLogs"
  }
  enabled_metric {
    category = "AllMetrics"
  }
}
