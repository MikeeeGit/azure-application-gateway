# CANDIDATE ONLY: apply after global + PPRD inputs. The live DNS alias and HTTP backend stay unchanged.
# Envoy uses .21 while existing direct/compatibility Services may retain .20 during migration.
backend_pools = {
  service = { dns_record = "service" }
  preview = { ip_addresses = ["10.81.4.21"] }
}
backend_settings = {
  web = {
    port                = 80
    host_name           = "web.example.test"
    connection_draining = { enabled = true, timeout = 300 }
    probe               = { host = "web.example.test", path = "/healthz" }
  }
  api = {
    port                = 80
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
