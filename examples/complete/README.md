# Hub/spoke and dual-AKS integration

[complete.tfvars](complete.tfvars) is the standalone equivalent of [global](../../config/global.tfvars) plus [pprd](../../config/uks/pprd/pprd.tfvars). Keep them aligned.

Network foundation owns hub/spoke VNets, aks01/aks02 and dedicated appgateway subnet, NSGs and routing. Separate AKS deployments/ingress controllers supply actual internal service IPs. This stack owns gateway/WAF and the apps.internal.example child zone.

Synthetic networks: hub 10.80.0.0/16, pprd 10.81.0.0/16, ingress 10.81.0.20/10.81.4.20 and gateway 10.81.8.0/24. The stable service alias initially selects aks01; preview targets aks02 directly.

The backend zone links to the gateway VNet and explicitly to the hub resolver VNet. Parent internal.example remains network-owned. No zone belongs to two states.

Shared certificates, HTTP redirects, /api/* routing, listener/path WAF, private/public listeners, 300-second connection draining and a response-header rewrite are demonstrated. Real certificate names and working health routes are prerequisites.

~~~bash
terraform test -test-directory=tests/targets -var-file=examples/complete/complete.tfvars
~~~

Follow [deployment](../../docs/deployment.md), then [cutover/rollback](../../docs/cutover.md). No AKS service or internal load balancer is invented by the input file.
