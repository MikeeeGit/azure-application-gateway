# Dual-AKS cutover and rollback

The full example keeps gateway, certificates, listeners and backend FQDN stable while an owned A record chooses an existing ingress service. This is a reviewed DNS target change, not automatic failover or weighted splitting.

1. Deploy/test the replacement workload on aks02. Confirm the actual internal ingress IP, Hosts, health endpoints and session/storage behavior.
2. Verify through the preview listener/backend or an equivalent private path. Replace the synthetic preview hostname and cover it with the certificate.
3. Change backend_dns_records.service.ip_addresses in the selected environment file from the verified aks01 IP to the verified aks02 IP. Keep the stable alias, listeners and pool names.
4. Run shared tf_plan, review the DNS-record change and apply that saved plan.
5. Check DNS through the real resolver path, gateway backend health and application requests. Observe both clusters and gateway logs.
6. Keep aks01 serving while DNS caches, connections and sessions converge. Decommission only through a separate reviewed change.

Application Gateway refreshes FQDNs based on TTL and can retain a last-known-good address if resolution fails. A 30-second TTL is not a fixed cutover deadline or zero-downtime guarantee. [Microsoft DNS behavior](https://learn.microsoft.com/en-us/azure/application-gateway/application-gateway-faq#how-is-the-ip-address-for-an-fqdn-based-backend-server-updated).

Optional connection_draining settings govern gateway backend updates/removals; they do not force DNS convergence or prove application session safety. The full example sets 300 seconds; determine a suitable value for your service.

Rollback restores the previously verified IP in the same record, generates/reviews a new plan and verifies traffic again. Never apply a stale saved plan after editing configuration, and do not delete the DNS record to switch targets.

Direct-IP mode changes backend_pools instead, causing a gateway update with different timing. Neither mode creates or switches Kubernetes ingress resources.
