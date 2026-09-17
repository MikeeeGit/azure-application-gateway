# Basic TLS/WAF example

[basic.tfvars](basic.tfvars) supplies standalone root inputs: one existing backend, one HTTPS listener with HTTP redirect, a public frontend and enabled WAF.

Replace synthetic IDs, existing subnet/VNet and vault/secret references, hostname and ingress IP. Keep tenant/subscription mappings aligned with delivery.azure.json. Prepare [prerequisites](../../docs/deployment.md).

From the repository root:

~~~bash
terraform init -backend=false
terraform test -test-directory=tests/targets -var-file=examples/basic/basic.tfvars
~~~

To deploy with shared helpers, transfer these inputs to private global/environment files and update the manifest consistently. Helpers select layered config; they do not automatically load this example file.
