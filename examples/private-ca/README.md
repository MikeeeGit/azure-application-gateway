# Explicit private CA trust for HTTPS backends

This additive profile allows Application Gateway WAF_v2 to validate an Envoy backend certificate issued by a private test or organisational CA. Existing deployments retain their default trust settings when `trusted_root_certificates` is empty. Frontend listener certificates still use the separately managed Key Vault certificate references.

1. Obtain the **public root CA certificate**, as a single PEM `CERTIFICATE` block. Verify its fingerprint, CA constraints and validity using `openssl x509 -in root-ca.pem -noout -fingerprint -sha256 -text`. Never pass a private key, PFX, password or whole server chain to this input. Terraform checks the PEM shape and references; the certificate's validity and actual backend chain require runtime qualification.
2. Add its public PEM contents to `trusted_root_certificates` under a stable name. The module sends its base64 DER certificate data to Azure. That public certificate is present in the plan/state.
3. Add the name to `trusted_root_certificate_names` for each intended **HTTPS** backend setting. Keep the full existing settings map, including Host, port, probe and connection draining. Undeclared, duplicate and HTTP-only root references are rejected.
4. Deploy the backend leaf certificate and complete intermediate chain to Envoy through the existing Key Vault/CSI path. Its SANs must cover the exact backend Host/SNI names. Keep certificate-chain and hostname verification enabled.
5. Apply a reviewed gateway plan, inspect backend health, then make CA-validated requests through each stable/preview listener.

The input shape in an environment tfvars file is:

```hcl
trusted_root_certificates = {
  lab = <<-PEM
    -----BEGIN CERTIFICATE-----
    REPLACE_WITH_THE_PUBLIC_ROOT_CA_CERTIFICATE
    -----END CERTIFICATE-----
  PEM
}

# Illustrates one setting. Merge the new field into ALL relevant entries of the
# complete private backend_settings map; do not discard API/preview settings.
backend_settings = {
  web = {
    port                           = 443
    protocol                       = "Https"
    host_name                      = "web.example.test"
    trusted_root_certificate_names = ["lab"]
    connection_draining            = { enabled = true, timeout = 300 }
    probe                          = { host = "web.example.test", path = "/healthz" }
  }
}
```

The placeholder is intentionally not a usable certificate. For generated JSON inputs, read the public PEM file as the string value of `trusted_root_certificates.lab`; do not base64-encode that input yourself. The ordinary delivery helpers read only the documented global and selected environment tfvars files. A third example file is not loaded automatically.

A disposable lab can retain reserved `example.test` hostnames with an explicitly trusted test CA. No public DNS registration is needed for a local request that selects the actual gateway address while preserving SNI and Host:

```bash
curl --fail --show-error --cacert root-ca.pem \
  --resolve "web.example.test:443:$GATEWAY_PUBLIC_IP" \
  https://web.example.test/version
```

The frontend certificate must independently cover `web.example.test`; using the same lab CA for both hops is an explicit test choice. Repeat web/API and preview checks, then use the existing [cutover and rollback procedure](../../docs/cutover.md). An uploaded root or successful Terraform apply alone does not establish that the gateway can reach and validate the backend.

Root rotation needs an overlap period: add the replacement root, issue/deploy the replacement backend chain, verify both slots and gateway health, then remove the previous root through another reviewed plan.

[Microsoft backend certificate requirements](https://learn.microsoft.com/en-us/azure/application-gateway/certificates-for-backend-authentication) describe v2 root trust and backend intermediate chains. The [AzureRM resource schema](https://registry.terraform.io/providers/hashicorp/azurerm/4.81.0/docs/resources/application_gateway) documents the corresponding trusted-root fields.
