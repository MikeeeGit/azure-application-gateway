# New empty gateway deployment after both Envoy HTTPS endpoints are verified.
# Validation: load after global and PPRD tfvars. Helper delivery: merge these
# complete maps into the private PPRD target, preserving unrelated entries.
backend_settings = {
  web = {
    port                = 443
    protocol            = "Https"
    host_name           = "web.example.test"
    connection_draining = { enabled = true, timeout = 300 }
    probe               = { host = "web.example.test", path = "/healthz" }
  }
  api = {
    port                = 443
    protocol            = "Https"
    host_name           = "api.example.test"
    connection_draining = { enabled = true, timeout = 300 }
    probe               = { host = "api.example.test", path = "/healthz" }
  }
  preview = {
    port                = 443
    protocol            = "Https"
    host_name           = "web.example.test"
    connection_draining = { enabled = true, timeout = 300 }
    probe               = { host = "web.example.test", path = "/healthz" }
  }
}
backend_dns_records = {
  service = { ip_addresses = ["10.81.0.21"], ttl = 30 }
}
backend_pools = {
  service = { dns_record = "service" }
  preview = { ip_addresses = ["10.81.4.21"] }
}
