# Deployment order

## Prepare delivery and network

Use shared delivery bootstrap for state and private deployment identities. Public source CI has no live deployment credentials.

Deploy network foundation first. The complete synthetic scenario uses hub 10.80.0.0/16 and pprd spoke 10.81.0.0/16, with aks01 10.81.0.0/22, aks02 10.81.4.0/22, dedicated appgateway 10.81.8.0/24, private-endpoints 10.81.9.0/24 and services 10.81.10.0/24.

For the standard public/private v2 example, keep the gateway subnet dedicated, allow expected clients 80/443, GatewayManager TCP65200–65535 and AzureLoadBalancer probes, and preserve required Internet outbound access. Do not attach an AKS forced-tunnel route table. Keep backend/DNS paths reachable; a /24 leaves scaling/maintenance space. [Microsoft requirements](https://learn.microsoft.com/en-us/azure/application-gateway/configuration-infrastructure).

Private-only mode requires the subscription's EnableApplicationGatewayNetworkIsolation feature and its private-deployment network requirements. This Terraform does not register features. [Microsoft private-only prerequisites](https://learn.microsoft.com/en-us/troubleshoot/azure/application-gateway/error-codes/application-gateway-frontend-ip-cannot-have-public-ip-subnet-error).

Validate zone support for your chosen region/SKU. Name/zone changes can replace resources; no ignore-changes or unconditional prevent-destroy flags hide that plan.

## Prepare certificates and identity

Provision an enabled, exportable PFX certificate in the existing vault with SANs covering real listener hostnames. Supply its **versionless secret URI**, not a certificate resource ID. The user-assigned identity needs Secret Get or Key Vault Secrets User and network access to the vault. Versionless references permit rotation. [Microsoft Key Vault integration](https://learn.microsoft.com/en-us/azure/application-gateway/key-vault-certs).

For a private-endpoint vault, prove DNS resolution and connectivity from the gateway/resolver path. Restricted public vaults require their documented network configuration. RBAC alone does not provide connectivity.

Terraform orders the gateway after managed permission resources. This does not prove directory/RBAC propagation or network readiness. New managed identities use explicit ServicePrincipal assignment type and skip an unnecessary directory lookup. For a transient authorization failure, verify grants/connectivity, allow propagation and generate a fresh reviewed plan before retrying. Do not grant Crypto User or Certificates Officer to work around it.

For pre-established access, supply existing_identity and existing mode, with the platform owner granting access before this stack runs.

## Prepare backends

Deploy AKS clusters and platform/application services independently. The maintained Envoy profile allocates private HTTPS frontends `10.81.0.21`/`10.81.4.21`; the app uses ClusterIP plus HTTPRoute. For an empty installation use the [HTTPS-first profile](../examples/https-first/README.md). The retained direct-Service example instead uses `10.81.0.20`/`10.81.4.20` over HTTP. The migration profile deliberately preserves a serving direct endpoint until cutover. Neither these addresses nor their Services are created by the AKS root or this gateway stack; verify actual allocation and responses first.

Deploy ingress routes for configured Hosts and health paths, verify them from an equivalent network location, and allow gateway-to-backend ports through NSGs/firewalls. Do not use AGIC to reconcile this Terraform-owned gateway.

## Deploy and verify

Replace synthetic values everywhere. Keep the apps.internal.example child zone owned by this stack, with internal.example parent owned by network foundation. Hub-proxy designs need hub and spoke links; the complete example supplies both. Avoid duplicate Key Vault zone links across states.

Merge the chosen gateway profile into private `config/uks/pprd/pprd.tfvars`, preserving unrelated values and replacing its complete backend maps. The helpers read only global and selected target tfvars; example files are not included automatically. Run tf_setup, tf_init, tf_plan, review, and tf_apply through the shared helpers. Owned DNS records/links are explicit gateway dependencies, but a mock plan does not prove live resolution.

Before publishing DNS, check backend health, each Host, certificate chain, redirect, public/private listener, path fallback, rewrite and WAF policy. Review logs and tune only service-specific false positives. Public/private client DNS publication remains separately owned.

Use [cutover and rollback](cutover.md) for switching clusters; keep the old cluster available until replacement traffic is proven and drained.


## Integrated sample without an ingress controller

The retained **direct-Service profile** in the [platform demo](https://github.com/MikeeeGit/aks-platform-demo) creates one internal Kubernetes LoadBalancer Service per cluster at the `.20` example backend addresses. For this single application the gateway can use those private endpoints directly; no ingress controller is required. Shared Kustomize delivery preserves the same container digest across aks01 and aks02. Check Service address assignment, private health endpoints and expected release/slot metadata before configuring or changing the gateway target.

The optional [shared firewall](https://github.com/MikeeeGit/azure-firewall) owns AKS egress policy; the separate routing add-on never attaches AKS forced-tunnel tables to the gateway subnet.
