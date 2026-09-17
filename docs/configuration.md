# Configuration and ownership

Delivery identity/backend selection is in delivery.azure.json; resources are configured through global and environment tfvars. Full types and guards are in [variables.tf](../variables.tf) and [waf_variables.tf](../waf_variables.tf).

The complete subscription_id_map and tenant_id must match the manifest. The environment's subscription alias and selected region must agree with its delivery entry. Providers target the manifest's tenant/subscriptions directly; mismatching tfvars fail rather than silently retargeting a deployment.

| Required input | Meaning |
|---|---|
| tenant_id, subscription_id_map, subscription | Explicit delivery-aligned target |
| location, location_abbreviated, environment | Region and naming labels |
| network OR network_state | Exactly one existing network source |
| backend_pools | Named IP lists, FQDN lists or owned DNS aliases |
| backend_settings | Backend port/protocol, Host and optional health probes |
| listeners | Hostnames, frontends, priorities and route/redirect settings |

Resource names default to region/environment plus appgateway and appgateway-rg suffixes. Explicit overrides are supported. Environment tags override global tags.

## Network

The smallest dependency is network = {subnet_id, subnet_cidr, virtual_network_id}. Use network foundation's logical appgateway subnet ID and prefix outputs.

Alternatively, network_state accepts explicit Azure backend subscription, resource group, account, container and key, plus subnet_key (default appgateway). It reads existing subnet_ids and **string-valued** subnet_address_prefixes maps using AzureAD. State readers can access the whole state snapshot; grant deliberately. Nothing infers a backend from estate naming.

The private frontend defaults to subnet host 7; private_frontend.ip_address overrides it. Azure-reserved and out-of-subnet addresses are rejected.

## Listeners and paths

Both frontends are enabled by default, but each listener selects public or private explicitly. A private frontend alone does not create a private listener. Private-only deployment prerequisites are in [deployment](deployment.md).

HTTPS listeners refer to certificates map keys, defined once even when shared. HTTP may forward or redirect to an explicit HTTPS listener.

A forwarding listener selects backend_pool and backend_settings. Its ordered paths list creates a real URL path map and PathBasedRouting rule, with default fallback from the listener. Each path chooses pool/settings and optional WAF/rewrite keys. Order specific patterns before broad ones.

rewrite_rule_sets supports request/response header maps and optional URL path/query changes. No forwarded-header rewrite or Front Door restriction is added automatically.

## Backends

Choose exactly one source per pool: ip_addresses, fqdns or dns_record. The stack does not discover Kubernetes services; supply ingress IPs verified in your cluster/network.

Backend port/protocol are independent of frontend HTTPS. Examples terminate TLS at the gateway and forward HTTP to private ingress. Set Https for re-encryption with a matching, trusted backend certificate. This edition uses provider/default public-CA trust; it does not configure private-CA roots.

Probe Host is its explicit host, otherwise backend host_name. A probe cannot silently inherit an unrelated public hostname. Configure a working health endpoint; this stack creates no ingress route or /healthz handler.

Affinity defaults to disabled rather than the original forced enabled setting. Optional connection_draining = {enabled=true, timeout=300} exposes backend update/removal draining, with timeout 1..3600 seconds. It is omitted by default and enabled in the complete example. DNS switches still require separate TTL/session observation.

## TLS access

certificate_subscription selects the provider alias for permission resources and optional Key Vault DNS links, defaulting to the workload alias. The vault ID must match that subscription.

certificate_access_mode is rbac (Secrets User), access_policy (Secret Get), or existing (no permission changes). Existing access must be established before deployment. existing_identity supplies a user-assigned identity resource/principal/tenant ID; null creates one.

When permissions are managed here, certificate secret URI hosts must match the one configured vault. Multi-vault access must be managed externally with existing mode. No certificate bytes, passwords or secret values are fetched into Terraform.

key_vault_private_dns_link optionally links the gateway VNet to an existing vault zone in the certificate subscription. Omit it when network foundation owns the link. A separate DNS-subscription zone should have its link managed by that DNS/network stack.

## WAF

The global_waf_policy key is attached to the gateway. A listener/path policy replaces the broader policy; rules are not merged. Required baseline controls must be present in every overriding policy. [Microsoft precedence](https://learn.microsoft.com/en-us/azure/web-application-firewall/ag/policy-overview).

Policies default to enabled Prevention and request-body inspection. Managed rules are explicitly DRS2.1/BotManager1.0. rule_group_overrides maps group names to **disabled** rule IDs. Start with empty overrides/exclusions. Custom rules support selectors and rate limiting; priorities/names must be unique.

Each collection is inline or loaded from files.custom_rules, files.rule_group_overrides, and files.managed_rule_exclusions. Paths are relative to waf_config_root, default config/all/waf-policy. Shapes match the inline schema. Empty collections are [] for custom/exclusions and {} for overrides; missing, malformed or empty files fail. The shipped synthetic rule logs a sample header and installs no Allow bypass or blanket geo restriction.

## DNS ownership

backend_dns_zone creates a new, solely owned private zone. backend_dns_records supplies IPs/TTLs; a pool's dns_record key creates a stable FQDN. Never create the same zone from two states. Multiple environments sharing a hub need distinct child zones, such as pprd.apps.internal.example and prd.apps.internal.example; two independently owned zones with the same name cannot both link to that hub.

The gateway VNet link is automatic. backend_dns_link_virtual_network_ids adds resolver/consumer VNets with unique IDs and nonreserved keys. Include the hub when spoke DNS goes through a hub firewall proxy/resolver. These links do not configure DNS servers or forwarding.

Public DNS is external. Publish public hostnames to the gateway public IP after verification; private client DNS must resolve private hostnames to the private frontend separately.
