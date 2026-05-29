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
