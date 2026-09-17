# Changelog

## Unreleased

- Public Application Gateway WAF_v2 stack derived from AZ-TF-appgateway-fd and AZ-TF-MOD-waf-policy.
- Remove all Front Door resources, dormant configuration and estate-specific rules/data.
- Add typed, generic listeners/pools/settings, real path routing and first-class JSON WAF policy inputs.
- Retain TLS via Key Vault with unique certificates, least-privilege identity access and explicit dependency ordering.
- Add public/private frontends, correct probe Host selection, optional backend DNS and dual-AKS cutover examples.
- Add credential-free mocked tests and documented deployment prerequisites.
