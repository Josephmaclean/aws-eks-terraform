# Private EKS Infrastructure

Terraform for a private EKS environment on AWS. This first step creates the base VPC network:

- VPC with DNS support enabled
- Two public subnets across availability zones
- Two AWS Network Firewall endpoint subnets across availability zones
- Two private subnets across availability zones
- Internet gateway for public subnet ingress and egress
- AWS Network Firewall in front of the public subnets, currently configured with an allow-all stateful rule
- NAT gateway in a public subnet for private subnet internet egress
- Dedicated route tables for each subnet
- Kubernetes subnet tags for future EKS load balancers
- Private EKS cluster with managed node groups for primary and ML workloads
- Karpenter AWS-side IAM, interruption queue, and example NodePool manifests
- AWS Load Balancer Controller IAM and bastion Helm bootstrap
- Terraform-managed SSM bootstrap for Karpenter, AWS Load Balancer Controller, Argo CD, and the Argo CD root Application
- Private SSM bastion/admin host with kubectl and helm
- Terraform destroy-time cleanup for Kubernetes-created AWS dependencies

## Usage

```sh
terraform init
terraform plan
terraform apply
```

Copy `terraform.tfvars.example` to `terraform.tfvars` if you want to override the defaults.

By default Terraform uses the private bastion to install Karpenter, AWS Load
Balancer Controller, Argo CD, and the Argo CD root `Application` through SSM.
This keeps Terraform usable from a local machine even when the EKS API endpoint
is private-only. The root application is read from the configured Git repository
URL and credentials stored in Secrets Manager.

## Destroy

Use Terraform for teardown:

```sh
terraform apply -destroy
```

During destroy, Terraform first runs a local AWS CLI cleanup for
Kubernetes-created AWS dependencies. It waits for or removes load balancers,
terminates any remaining Karpenter-created instances, waits for ELB network
interfaces to clear, and removes leftover `k8s-*` security groups before
Terraform deletes the EKS cluster and VPC.

## Layout

```text
.
├── global_variables.tf      # Shared provider/name/tag inputs
├── main.tf                  # Root orchestration and bootstrap wiring
├── vpc_variables.tf         # VPC inputs
├── eks_variables.tf         # EKS, Karpenter, bastion, and Argo CD inputs
├── outputs.tf               # Root outputs, including grouped "vpc" and "eks" objects
└── modules/
    ├── bastion/             # Private SSM bastion with kubectl and helm
    ├── eks_components/      # EKS cluster, node groups, Karpenter, AWS LBC IAM, manifests, and scripts
    │   └── argocd/          # Optional Argo CD Helm bootstrap
    └── vpc_components/
        ├── vpc.tf           # VPC and internet gateway
        ├── subnets.tf       # Public, firewall, and private subnets
        ├── network_firewall.tf
        ├── nat.tf
        ├── routes.tf
        ├── variables.tf
        ├── locals.tf
        └── outputs.tf
```

## Consuming Outputs

Downstream Terraform stacks can consume the grouped root outputs from remote state:

- `vpc`: VPC ID, CIDR, subnet IDs, NAT gateway ID, and Network Firewall ARN.
- `eks`: cluster endpoint/name, cluster security group, node group ARNs, Karpenter IAM/queue values, AWS Load Balancer Controller role ARN, bastion access commands, and Argo CD bootstrap metadata.

The older individual outputs, such as `vpc_id`, `private_subnet_ids`, `eks_cluster_name`, and `karpenter_node_role_name`, are still kept for compatibility.

## Routing Shape

- Internet gateway route table sends public subnet CIDRs to the Network Firewall endpoints.
- Public subnet route tables send default internet traffic to the Network Firewall endpoints.
- Firewall subnet route tables send default internet traffic to the internet gateway.
- Private subnet route tables send default internet traffic to the NAT gateway in the public subnet.

## Argo CD Bootstrap

Argo CD is wired as a Helm bootstrap module. It can also create a root app when repository credentials are supplied through AWS Secrets Manager.

By default this stack keeps the EKS API private-only. Argo CD is bootstrapped from the private bastion host by an SSM association, so Terraform does not need direct network access to the Kubernetes API from your laptop.

For an infra-only apply without Argo CD bootstrap, disable:

```hcl
enable_bastion_argocd_bootstrap = false
```

The default Argo CD server service type is `ClusterIP`.

To create the Argo CD root app during bootstrap, store repository credentials in AWS Secrets Manager as JSON and set `argocd_repo_secret_id`.

Example secret value:

```json
{
  "repo_url": "https://github.com/example/platform-gitops.git",
  "github_username": "x-access-token",
  "github_token": "ghp_example"
}
```

Relevant variables:

```hcl
argocd_repo_secret_id           = "" # defaults to "${name}/github/repo"
argocd_repo_secret_arn          = "arn:aws:secretsmanager:eu-west-2:123456789012:secret:private-eks/github/repo-AbCdEf"
argocd_repo_url                 = ""
argocd_repo_url_key             = "repo_url"
argocd_repo_username_key        = "github_username"
argocd_repo_password_key        = "github_token"
argocd_root_app_name            = "root"
argocd_root_app_path            = "."
argocd_root_app_manifest_path   = "root-app.yaml"
argocd_root_app_target_revision = "HEAD"
```

Bump `argocd_bootstrap_revision` to rerun the SSM bootstrap after changing the secret or root app settings.

## Bastion Kubectl

After `terraform apply`, start a private SSM session:

```sh
terraform output -raw bastion_ssm_start_session_command
```

Run the printed command. Inside the session:

```sh
configure-kubectl
kubectl get nodes
```

The bastion has no public IP and no inbound security group rules.
