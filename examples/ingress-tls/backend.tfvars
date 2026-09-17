# EXPLICIT TRAFFIC CUTOVER: use only after the candidate profile is verified.
# Apply AFTER config/global.tfvars and config/uks/pprd/pprd.tfvars.
# These replace the complete backend_settings map, preserving all referenced keys.
# The controller must already serve a trusted certificate for each replacement Host/SNI.
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

# A separately reviewed DNS change chooses the verified candidate; no app pipeline edits this.
backend_dns_records = {
  service = { ip_addresses = ["10.81.4.21"], ttl = 30 }
}
backend_pools = {
  service = { dns_record = "service" }
  preview = { ip_addresses = ["10.81.4.21"] }
}
