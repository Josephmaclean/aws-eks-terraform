# Argo CD Bootstrap

This module installs Argo CD with the official Argo Project Helm chart repository.

It intentionally does not create a root `Application` yet. Once the cluster is stable, add the GitOps bootstrap app separately so Terraform only owns the Argo CD installation boundary.

## Usage

The root module enables this by default. Because the EKS API endpoint is private, Terraform must run from a network that can reach the private endpoint. If you want an infra-only apply first, disable:

```hcl
enable_argocd = false
```

The default server service type is `ClusterIP`. Use port-forwarding, VPN, or an internal ingress/load balancer when you are ready to expose the UI.
