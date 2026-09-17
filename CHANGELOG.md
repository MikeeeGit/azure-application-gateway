# Changelog

## Unreleased

- Bind the basic example certificate provider explicitly to its workload vault subscription so shared-global layering stays valid.

- Reconcile September source: expose default-on WAF request-body size enforcement and demonstrate explicit environment-specific JSON policies, with mocked regression coverage.

- Public Application Gateway WAF_v2 stack derived from AZ-TF-appgateway-fd and AZ-TF-MOD-waf-policy.
- Remove all Front Door resources, dormant configuration and estate-specific rules/data.
- Add typed, generic listeners/pools/settings, real path routing and first-class JSON WAF policy inputs.
- Retain TLS via Key Vault with unique certificates, least-privilege identity access and explicit dependency ordering.
- Add public/private frontends, correct probe Host selection, optional backend DNS and dual-AKS cutover examples.
- Add credential-free mocked tests and documented deployment prerequisites.
