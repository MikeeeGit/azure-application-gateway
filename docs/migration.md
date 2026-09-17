# Source provenance and migration

Rebuilt from archived AZ-TF-appgateway-fd and AZ-TF-MOD-waf-policy, reconciled against the 17 September 2026 archive. Originals were unchanged. No state, exported cloud snapshots, environment tfvars, certificate material, real identifiers or application policy exceptions were copied.

References below identify original archive entry locations:

| Source | Capability / public change |
|---|---|
| AZ-TF-appgateway-fd/main.tf:351 | WAF_v2, autoscale, identity, TLS and frontends |
| main.tf:386 | Existing subnet; replace inferred estate state paths with explicit network/state inputs |
| main.tf:413 | IP/DNS pools; expose explicit inputs and owned stable aliases |
| main.tf:422 | Multi-host listeners and per-site WAF; replace hard-coded application policy names |
| main.tf:442 | HTTP redirects now use explicit target names |
| main.tf:455 and :1521 | Original Basic routing ignored URL patterns; public paths create real URL path maps |
| main.tf:489 | Health probes now use explicit probe/backend Host |
| main.tf:526 | Shared Key Vault certificates deduplicated by map key |
| main.tf:539 | Rewrites retained without implicit forwarded-header changes |
| main.tf:604 | Optional allLogs/AllMetrics diagnostics |
| main.tf:623–875 | Dormant/commented Front Door removed with variables/outputs/docs |
| main.tf:887 and :1008 | JSON WAF collections retained using generic policy keys |
| main.tf:1139 and :1197 | Identity/access retained; least-privilege Secret Reader and explicit dependency |
| main.tf:1289 | Hard-coded public DNS moved outside stack ownership |
| main.tf:1409 | Backend private DNS retained with explicit VNet link IDs |
| AZ-TF-MOD-waf-policy/main.tf:99 | Custom/rate rules retained, optional match selector added |
| AZ-TF-MOD-waf-policy/main.tf:173 | DRS2.1/BotManager1.0 and overrides/exclusions retained |
| AZ-TF-MOD-waf-policy/main.tf:34 | Unused country-list default removed; geo rules must be explicit |

## Deliberate differences

- Named listeners, pools, settings, certificates and policies replace application-specific inputs. This is a new public interface, not a state-compatible drop-in.
- Original agw_listener entries split into listener/settings/certificate definitions. ips/use_fqdn becomes ip_addresses, fqdns or dns_record.
- Frontend is chosen per listener; original listeners always used the public frontend.
- TLS defaults to the stricter 2022 S predefined policy. Certificates use versionless secret references; managed RBAC is default.
- Affinity defaults off rather than forced on. Connection draining is explicit and optional.
- Zones are explicit instead of environment-derived; gateway/public IP use the same list. Lifecycle replacement is not hidden.
- Original application allowlists, exclusions, disabled rules and blanket country defaults are not published. Synthetic rules log a sample header.
- Certificate roles are least privilege. Original private-CA trusted roots were empty; this edition does not claim that feature.
- JSON files are first-class inputs; missing/malformed/empty files fail. Valid empty collections remain explicit.
- Focused outputs replace the original sensitive whole-gateway object.

Existing infrastructure needs a separately reviewed import/state-address migration and replacement analysis. Do not point this stack at production state merely because names look similar. Source conversion removed Front Door code; no live Front Door resources were deleted.

The repository follows public framework v0.2: layered config, explicit AzureAD backends, provider checksums, Terraform1.16.3/AzureRM>=4.33,<5, credential-free tests and saved-plan review. Its state adapter consumes logical subnet keys with string-valued prefix outputs.

## Updated source reconciliation

The later source separates preproduction WAF JSON from the shared policy directory and adds request-body size enforcement to the WAF child. The public interface preserves directory selection explicitly through `waf_config_root`, with a synthetic PPRD example, and now exposes per-policy `request_body_enforcement` (default true). Match-variable selectors were already supported. Private policy exceptions, source-address annotations, partner allowlists and legacy gateway instances are deliberately not copied. The modern WAF_v2, listener/path routing, identity and dual-backend cutover remain the supported design.
