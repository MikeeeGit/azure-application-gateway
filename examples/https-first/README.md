# New installation with HTTPS backends from the start

Use this additional profile for an **empty** Application Gateway deployment after both Envoy endpoints are ready. It preserves all existing direct-Service and migration examples. It does not require a legacy `.20` Service, and it must not be used as a shortcut for migrating an already serving HTTP gateway.

| Route | Backend | Protocol and intended release |
|---|---|---|
| Stable web/API/private listener | `service.apps.internal.example` → aks01 `10.81.0.21` | HTTPS443; verified active release |
| Preview listener | aks02 `10.81.4.21` | HTTPS443; verified candidate release |

The platform profile owns Envoy LoadBalancers and TLS Gateways. The app owns ClusterIP Services and HTTPRoutes. Pipeline-driven Kustomize or [Argo CD](https://github.com/MikeeeGit/aks-delivery-templates/blob/main/docs/delivery-methods.md) can deliver the same app; neither owns this Terraform gateway or changes its active backend implicitly.

## Prepare and integrate

1. Follow the [sandbox runbook](https://github.com/MikeeeGit/terraform-delivery-templates/blob/main/docs/azure/sandbox-deployment.md) and [deployment prerequisites](../../docs/deployment.md). Replace all synthetic network/resource IDs and hosts in your private consumer.
2. Prove both actual `.21` private frontends, trusted HTTPS, selected slot/revision and health endpoints. The supplied backend trust uses public CAs. Replace `.test` names with controlled names and provide a complete public-CA chain matching the configured web/API Host/SNI. Private/self-signed CAs require a separate trusted-root implementation; never disable TLS validation.
3. Prepare the separately owned Key Vault frontend certificate and gateway identity/network access. Its SANs must cover the chosen public, preview and optional private listener names.
4. Merge [https.tfvars](https.tfvars)' complete `backend_settings`, `backend_dns_records` and `backend_pools` maps into the private `config/uks/pprd/pprd.tfvars`. Preserve unrelated entries and replace existing assignments instead of duplicating them. The helpers and private component pipeline read **only** global and selected target tfvars; they do not automatically load this example file. Terraform replaces whole maps, so stacking tfvars is not a recursive merge.
5. Run the normal `tf_setup`/`tf_init`/`tf_plan` cycle. Check that every backend uses HTTPS443, live points only to aks01 `.21`, preview points only to aks02 `.21`, and the Host/probe/certificate contract matches the app. Review the initial saved plan before applying it.
6. Verify Azure backend health and requests through every intended frontend before public DNS publication. DNS and client traffic remain separately owned.

After the first release, test inactive-slot updates before using [cutover and rollback](../../docs/cutover.md). Retarget preview to the inactive slot deliberately; changing a deployment's image does not switch the stable alias. Keep the previous healthy source/digest and backend configuration available.

## Credential-free profile test

Run from the repository root:

```bash
terraform init -backend=false -input=false -lockfile=readonly
terraform test -test-directory=tests/https-first \
  -var-file=config/global.tfvars -var-file=config/uks/pprd/pprd.tfvars \
  -var-file=examples/https-first/https.tfvars
```

This explicitly layers the example for validation and uses only mocked providers, including mocked apply/teardown to resolve computed gateway blocks. It checks the fresh active/preview split, HTTPS probes, Host settings and absence of legacy `.20` backend targets. It creates no Azure resources and cannot qualify real network, identity, certificates or WAF behavior.
