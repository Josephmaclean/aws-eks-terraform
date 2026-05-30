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
- Private SSM bastion/admin host with kubectl and helm
- Argo CD bootstrap from the bastion through SSM

## Usage

```sh
terraform init
terraform plan
terraform apply
```

Copy `terraform.tfvars.example` to `terraform.tfvars` if you want to override the defaults.

## Layout

```text
.
├── main.tf                  # Root orchestration
├── variables.tf             # Root inputs
├── outputs.tf               # Root outputs
├── eks/                     # EKS cluster, node groups, Karpenter IAM, Karpenter manifests
├── bastion/                 # Private SSM bastion with kubectl and helm
├── argocd/                  # Optional Argo CD Helm bootstrap
└── modules/
    └── vpc/
        ├── vpc.tf           # VPC and internet gateway
        ├── subnets.tf       # Public, firewall, and private subnets
        ├── network_firewall.tf
        ├── nat.tf
        ├── routes.tf
        ├── variables.tf
        ├── locals.tf
        └── outputs.tf
```

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
