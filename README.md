# Azure Application Gateway

A public Terraform deployment stack for Application Gateway **WAF_v2**, with Key Vault TLS, multiple hostnames, path routing, private/public listeners and reusable WAF configuration.

This standalone edition derives from AZ-TF-appgateway-fd and AZ-TF-MOD-waf-policy. Front Door and estate-specific configuration are removed. Included identifiers, names, addresses and rules are synthetic. Apache-2.0 licensed.

## Architecture

~~~mermaid
flowchart LR
  Clients --> Gateway["Application Gateway WAF_v2"]
  PrivateClients["Private clients"] --> Gateway
  Vault["Existing Key Vault certificates"] --> Identity["User-assigned identity"]
  Identity --> Gateway
  Policies["Global, listener and path WAF"] --> Gateway
  Gateway --> Alias["service.apps.internal.example"]
  Alias --> AKS01["aks01 internal ingress"]
  Alias -. "reviewed DNS cutover" .-> AKS02["aks02 internal ingress"]
  Gateway --> Other["IP/FQDN backends"]
~~~

This stack owns the gateway, resource group, optional public IP and identity, WAF policies, and optional backend private DNS. It consumes an existing dedicated subnet, vault/certificates and backend services. It does not provision AKS, ingress controllers, internal load balancers, public DNS or Front Door. Do not attach AGIC to reconcile this Terraform-owned gateway.

## Start here

1. Follow the [shared Azure setup guide](https://github.com/MikeeeGit/terraform-delivery-templates/blob/v0.2.0/docs/getting-started.md) for state storage and delivery identities.
2. Prepare the network, certificates and ingress services in [deployment order](docs/deployment.md). Use [HTTPS-first](examples/https-first/README.md) for a new Envoy deployment, or retain the existing direct/migration examples for their documented purpose. The [sandbox runbook](https://github.com/MikeeeGit/terraform-delivery-templates/blob/main/docs/azure/sandbox-deployment.md) connects all prerequisites.
3. Make a private deployment copy. Replace synthetic IDs in delivery.azure.json and config/global.tfvars; provide real existing network IDs, versionless certificate secret URIs and verified ingress IPs.
4. Review [configuration](docs/configuration.md), [complete integration](examples/complete/README.md) and [migration](docs/migration.md).
5. Use the shared helpers from the repository root:

~~~bash
az login --tenant <your-tenant-id>
source ../terraform-delivery-templates/scripts/azure/terraform-functions.sh
tf_setup azure-application-gateway pprd uks
tf_init
tf_plan
tf_apply
~~~

PowerShell uses the same commands after dot-sourcing the corresponding terraform-functions.ps1. Helpers load global tfvars then the selected region/environment file, verify delivery targeting, initialize the backend, save a bound plan and prompt before apply.

[Basic](examples/basic/README.md) supplies one backend and TLS listener. [Complete](examples/complete/README.md) demonstrates hub/spoke DNS, dual-AKS backend choice, redirects, real path routing and private/public listeners. Backend ingress services must already exist.

## Capabilities

- WAF_v2 autoscale, explicit zones, public/private frontend selection.
- Shared, unique Key Vault certificate definitions and one user-assigned identity.
- Least-privilege managed RBAC, legacy Secret Get access policy, or externally owned access.
- Independent pools, backend settings, explicit probe Hosts, affinity and optional connection draining.
- Host/path routing, redirects, request/response headers and URL rewrites.
- Generic global/listener/path WAF policies, custom/rate-limit rules, managed exclusions and disable overrides, inline or JSON.
- Optional private backend DNS and Log Analytics diagnostics.
- Focused gateway/address/identity/policy outputs.

DRS **2.1** and Bot Manager **1.0** are deliberate compatibility defaults. Microsoft recommends newer DRS2.2; changing versions requires a separately tested provider baseline and policy tuning. This repository does not label its default “latest.” [Microsoft rulesets](https://learn.microsoft.com/en-us/azure/web-application-firewall/ag/application-gateway-crs-rulegroups-rules).

## Validation

Tested CLI: **Terraform 1.16.3**. Constraints: Terraform >=1.9,<2; AzureRM >=4.33,<5. Provider checksums are committed. Public CI must use hosted, credential-free mocked tests.

~~~bash
terraform fmt -check -recursive
terraform init -backend=false -input=false
terraform validate
terraform test
terraform test -test-directory=tests/targets -var-file=config/global.tfvars -var-file=config/uks/pprd/pprd.tfvars
terraform test -test-directory=tests/targets -var-file=examples/basic/basic.tfvars
terraform test -test-directory=tests/targets -var-file=examples/complete/complete.tfvars
~~~

Mocks prove configuration contracts, not live Azure deployment, DNS reachability, certificate retrieval, WAF tuning or traffic cutover. Those checks require an explicitly selected sandbox and separately deployed prerequisites.

- [Configuration and ownership](docs/configuration.md)
- [Deployment prerequisites](docs/deployment.md)
- [Cutover and rollback](docs/cutover.md)
- [Source provenance and migration](docs/migration.md)
- [Contributing](CONTRIBUTING.md) · [Security](SECURITY.md) · [Changelog](CHANGELOG.md)

Optional [ingress TLS profile](examples/ingress-tls/README.md) preserves workload identity, CSI certificate synchronization and gateway-to-controller HTTPS as an explicit path beside the simple direct-ILB demo.

## CI change scope

Markdown-only edits use lightweight required GitHub checks and are excluded from automatic Azure validation builds. Changes to Terraform, application code, scripts, workflow definitions or executable examples still run full validation, including examples stored under docs/. Mixed changes also run full validation. Manual GitHub runs and unknown Git comparison ranges default to full validation.
