# HTTPS backend profile for in-cluster ingress

This explicit profile keeps Application Gateway WAF/TLS at the edge and re-encrypts traffic to the cluster gateway or ingress controller on port443. That controller terminates the backend TLS session and routes HTTP to the application. It works with the maintained Gateway API profile or a separately selected historical ingress compatibility profile; Terraform does not install either controller.

For a **new deployment with no existing HTTP path**, use the separate [HTTPS-first example](../https-first/README.md). The following sequence preserves an already serving direct/legacy HTTP deployment.

Start with [candidate.tfvars](candidate.tfvars) after `config/global.tfvars` and `config/uks/pprd/pprd.tfvars`. It points only the preview pool to the independently reserved Envoy candidate address `10.81.4.21` over HTTPS443. Live traffic still uses the stable DNS alias at `10.81.0.20` over HTTP80. The maintained controller uses `10.81.0.21`/`10.81.4.21`, leaving old direct/compatibility endpoints independent during migration. Do not skip this phase when moving an active HTTP demo.

After proving candidate readiness, [backend.tfvars](backend.tfvars) is an **explicit traffic cutover**: it changes the stable alias to `10.81.4.21` and all three backend settings (`web`, `api`, `preview`) to HTTPS443. Listeners, WAF rules, stable alias name and Host/SNI contract remain stable. The preview frontend hostname is independent; it forwards `web.example.test` to the candidate backend. App/Helm delivery does not select either Terraform phase automatically.

## Use these profiles with saved-plan delivery

The local `tf_setup`/`tf_plan` helpers and authenticated component pipelines read **only** `config/global.tfvars`, followed by `config/<region>/<environment>/<environment>.tfvars`. They do not discover example files or accept `TF_CLI_ARGS`/`TF_VAR_*` overrides. The three-file commands below are credential-free validation compositions.

For actual private delivery, merge the selected profile's complete `backend_settings`, `backend_dns_records` and `backend_pools` maps into the private PPRD target before the normal helper/pipeline cycle. Preserve unrelated entries, replace existing assignments rather than duplicating them, and replace synthetic hosts/addresses. Terraform replaces whole maps rather than recursively merging tfvars. Review the saved plan's exact active/preview destinations, Host/SNI and protocol/port changes. Keep the prior reviewed maps for rollback; changing profile after approval requires a new plan.

```bash
terraform test -test-directory=tests/ingress-candidate \
  -var-file=config/global.tfvars -var-file=config/uks/pprd/pprd.tfvars \
  -var-file=examples/ingress-tls/candidate.tfvars
terraform test -test-directory=tests/ingress-tls \
  -var-file=config/global.tfvars -var-file=config/uks/pprd/pprd.tfvars \
  -var-file=examples/ingress-tls/backend.tfvars
```

Run from the repository root. This uses mocked providers, including a mocked apply/teardown to resolve computed gateway blocks; it never calls Azure. Real infrastructure delivery uses a reviewed saved plan and private configuration.

## Required before planning the HTTPS transition

1. Install the selected controller/Gateway and prove its private LoadBalancer address. Do not simultaneously assign the same address to the old direct application Service. Use a distinct candidate IP during migration or a separately approved ownership transfer.
2. Follow the [AKS workload identity and CSI TLS profile](https://github.com/MikeeeGit/azure-aks-foundation/blob/main/examples/ingress-tls/README.md). A running mounting workload synchronizes `platform-demo-tls` in namespace `platform-demo`; the Gateway/Ingress must reference that Secret.
3. Replace the reserved `.test` hostnames with real controlled names. This module currently uses standard public-CA backend trust. Supply a complete valid certificate chain matching `web` and `api` backend Host/SNI names. Private/self-signed CA trust is not configured by this profile and must not be bypassed; it needs an explicit trusted-root extension before use. Frontend Key Vault certificates are separately owned and must also cover the public/preview frontend names.
4. From the gateway network, verify each private candidate over HTTPS443 using the real hostname, valid trust chain, `/healthz` and application routes. Check NSGs, controller source ranges and NetworkPolicy. Never disable certificate verification or substitute a Kubernetes API address for the backend.
5. Review/apply the candidate-only plan and verify the preview path while live traffic remains unchanged. Only after acceptance, generate a new explicit cutover plan using `backend.tfvars`: review both the live DNS target and protocol/port/probe changes together. Verify gateway backend health and actual requests afterward. Keep the prior endpoint and its exact HTTP/DNS configuration for rollback; returning to a previous HTTP endpoint requires reverting protocol and DNS together. Subsequent TLS-to-TLS rotations can use the ordinary [DNS cutover](../../docs/cutover.md), retargeting preview to the inactive slot first.

The public HTTP direct-ILB sample and controller candidate can coexist on their separately reserved addresses. Each address still has exactly one Service owner. This example does not claim automatic controller migration, automatic failover, database rollback or live Azure qualification. See [Microsoft end-to-end TLS behavior](https://learn.microsoft.com/en-us/azure/application-gateway/ssl-overview).
