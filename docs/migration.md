# Design and migration compatibility

This component provides WAF_v2, named listeners, explicit backend settings, URL path maps, certificate references and per-site WAF policies. Its input interface and native resource addresses require a reviewed migration when adopting existing infrastructure.

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

Existing infrastructure needs a separately reviewed import/state-address migration and replacement analysis. Do not point this stack at production state merely because names look similar. Front Door resources are outside this component.

The repository follows public framework v0.2: layered config, explicit AzureAD backends, provider checksums, Terraform1.16.3/AzureRM>=4.33,<5, credential-free tests and saved-plan review. Its state adapter consumes logical subnet keys with string-valued prefix outputs.

## WAF configuration

Use waf_config_root to select the intended policy directory. Per-policy request_body_enforcement defaults to true; match-variable selectors, exclusions and overrides are explicit inputs. Review rules for the target application rather than adopting synthetic examples as a production policy. Listener/path routing, managed identity and independently reviewed dual-backend cutover remain separate configuration concerns.
