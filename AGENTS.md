# Agents Guide — Infrastructure Operations

> Terraform · AWS · EKS · Karpenter

---

## Overview

This document defines the agent roles, responsibilities, tools, and workflows for provisioning and maintaining the AWS infrastructure platform. The current scope covers Terraform-managed infrastructure and EKS cluster setup with Karpenter for node autoscaling. Each agent has a clearly defined boundary and escalation path.

---

## Agent Roster

| Agent | Scope | Primary Tools |
|---|---|---|
| `infra-agent` | Terraform state, modules, and apply workflow | Terraform, AWS CLI, S3, DynamoDB |
| `cluster-agent` | EKS control plane, add-ons, and Karpenter | Terraform EKS module, kubectl, Helm, AWS EKS API |
| `network-agent` | VPC, subnets, security groups, NAT | Terraform, AWS VPC |
| `iam-agent` | IAM roles, IRSA, OIDC, AWS SSO | Terraform, AWS IAM |

---

## Agent Definitions

---

### `infra-agent`

**Purpose:** Single source of truth for all infrastructure provisioning. Owns Terraform root modules, remote state, and the plan → apply workflow.

**Responsibilities:**
- Manage Terraform workspaces per environment (`dev`, `staging`, `prod`)
- Maintain S3 + DynamoDB backend for remote state and locking
- Coordinate `plan` → `review` → `apply` workflow; no direct AWS console changes permitted
- Pin module versions and manage provider version constraints
- Surface Infracost diffs on every PR touching infrastructure

**Repository Layout:**
```
infra/
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── terraform.tfvars
│   ├── staging/
│   └── prod/
├── modules/
│   ├── vpc/
│   ├── eks/
│   ├── karpenter/
│   └── s3/
└── global/
    ├── iam/
    └── backend/
        ├── main.tf          # S3 bucket + DynamoDB table
        └── backend.hcl.tpl
```

**Backend Configuration:**
```hcl
# backend.hcl (per environment)
bucket         = "my-org-terraform-state"
key            = "prod/terraform.tfstate"
region         = "eu-west-1"
dynamodb_table = "terraform-state-lock"
encrypt        = true
```

**Standard Apply Workflow:**
```bash
terraform workspace select prod
terraform init -backend-config=backends/prod.hcl
terraform plan -out=tfplan -var-file=vars/prod.tfvars
# PR review of plan output required before apply
terraform apply tfplan
```

**Provider Versions:**
```hcl
terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
  }
}
```

**Escalation Triggers:**
- State lock held > 15 minutes → alert `cluster-agent` and `network-agent`, investigate holding process
- `terraform plan` shows destructive changes to EKS node groups or VPC → require explicit human approval before apply
- Backend S3 bucket policy drift detected → alert `iam-agent`
- Provider version constraint conflict → freeze applies until resolved

---

### `cluster-agent`

**Purpose:** Owns the EKS cluster lifecycle — control plane provisioning, managed add-ons, and Karpenter node autoscaling.

**Responsibilities:**
- Provision EKS control plane via the `terraform-aws-modules/eks` module
- Manage core cluster add-ons: VPC CNI, CoreDNS, kube-proxy, EBS CSI, EFS CSI
- Install and configure Karpenter as the sole node autoscaler (no Cluster Autoscaler)
- Define Karpenter `NodePool` and `EC2NodeClass` resources for each workload tier
- Manage EKS access entries (replacement for `aws-auth` ConfigMap)
- Coordinate Kubernetes version upgrades across control plane and nodes

**EKS Module (Terraform):**
```hcl
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "prod-cluster"
  cluster_version = "1.30"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Karpenter manages all worker nodes; only a small system node group
  # is provisioned via Terraform for system-critical workloads
  eks_managed_node_groups = {
    system = {
      instance_types = ["t3.medium"]
      min_size       = 2
      max_size       = 4
      desired_size   = 2
      taints = [{
        key    = "CriticalAddonsOnly"
        value  = "true"
        effect = "NO_SCHEDULE"
      }]
      labels = { role = "system" }
    }
  }

  cluster_addons = {
    coredns                = { most_recent = true }
    kube-proxy             = { most_recent = true }
    vpc-cni                = { most_recent = true }
    aws-ebs-csi-driver     = { most_recent = true }
    aws-efs-csi-driver     = { most_recent = true }
  }

  # Enable IRSA
  enable_irsa = true

  # Use access entries instead of aws-auth ConfigMap
  authentication_mode = "API"
}
```

**Karpenter Setup (Terraform):**
```hcl
module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 20.0"

  cluster_name = module.eks.cluster_name

  enable_v1_permissions = true
  enable_pod_identity   = true

  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }
}

resource "helm_release" "karpenter" {
  namespace        = "karpenter"
  create_namespace = true
  name             = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = "1.0.0"

  set {
    name  = "settings.clusterName"
    value = module.eks.cluster_name
  }
  set {
    name  = "settings.interruptionQueue"
    value = module.karpenter.queue_name
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.karpenter.iam_role_arn
  }
}
```

**Karpenter NodePool Definitions:**
```yaml
# General-purpose workloads
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: general
spec:
  template:
    spec:
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: default
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot", "on-demand"]
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["m", "c", "r"]
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["4"]
  limits:
    cpu: 1000
    memory: 2000Gi
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 1m
---
# EC2NodeClass
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  amiFamily: AL2023
  role: "KarpenterNodeRole-prod-cluster"
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: prod-cluster
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: prod-cluster
  tags:
    Environment: prod
    ManagedBy: karpenter
```

**Cluster Upgrade Protocol:**
1. Review EKS release notes and add-on compatibility matrix
2. Update `cluster_version` in Terraform, plan and apply (control plane upgrade)
3. Update each cluster add-on (`most_recent = true` or pin new version)
4. Update `amiFamily` or AMI alias in `EC2NodeClass` — Karpenter will rolling-replace nodes automatically via drift detection
5. Verify system node group AMI separately (`eksctl upgrade nodegroup` or replace via Terraform)
6. Validate all workloads healthy before closing the change

**Core Commands:**
```bash
# Update kubeconfig
aws eks update-kubeconfig --region eu-west-1 --name prod-cluster

# Check Karpenter-managed nodes
kubectl get nodes -l karpenter.sh/registered=true

# View NodePool status and limits
kubectl get nodepools -o wide

# Force node consolidation dry-run
kubectl annotate nodeclaim <name> karpenter.sh/do-not-disrupt=false

# Check Karpenter controller logs
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter -f
```

**Escalation Triggers:**
- Karpenter failing to provision nodes for > 5 minutes → check EC2 capacity in region, alert `network-agent` for subnet IP exhaustion
- Control plane upgrade fails mid-flight → freeze all other Terraform applies, escalate to `infra-agent`
- Add-on version incompatible with new cluster version → pin add-on version, open remediation PR

---

### `network-agent`

**Purpose:** Manages VPC topology, subnet layout, security groups, and NAT gateway configuration as the network foundation for EKS.

**Responsibilities:**
- VPC design: CIDR allocation, public/private/intra subnet layout, NAT gateways
- Tag subnets correctly for EKS and Karpenter discovery
- Manage security groups with least-privilege rules
- Ensure sufficient IP space per subnet for node and pod scaling

**VPC Module (Terraform):**
```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "prod-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  public_subnets  = ["10.0.0.0/20",   "10.0.16.0/20",  "10.0.32.0/20"]
  private_subnets = ["10.0.128.0/20", "10.0.144.0/20", "10.0.160.0/20"]
  intra_subnets   = ["10.0.192.0/28", "10.0.192.16/28","10.0.192.32/28"]

  enable_nat_gateway     = true
  single_nat_gateway     = false   # one per AZ for prod
  one_nat_gateway_per_az = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Required tags for EKS load balancer controller
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  # Required tags for EKS internal load balancers and Karpenter subnet discovery
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"    = 1
    "karpenter.sh/discovery"             = "prod-cluster"
  }

  tags = {
    Environment                              = "prod"
    "kubernetes.io/cluster/prod-cluster"     = "shared"
  }
}
```

**Network Layout:**
```
VPC: 10.0.0.0/16
├── Public Subnets    10.0.0.0/20 – 10.0.32.0/20   (NAT GW, ALB)
├── Private Subnets   10.0.128.0/20 – 10.0.160.0/20 (EKS nodes, Karpenter)
└── Intra Subnets     10.0.192.0/28 – 10.0.192.32/28 (EKS control plane ENIs)
```

**Security Groups:**
```hcl
# Cluster security group is managed by the EKS module.
# Add rules for specific cross-service access here.

resource "aws_security_group_rule" "nodes_to_secrets_manager" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = module.eks.node_security_group_id
  # AWS Secrets Manager uses the regional HTTPS endpoint; allow via prefix list
  prefix_list_ids   = [data.aws_ec2_managed_prefix_list.s3.id]
  description       = "Allow nodes to reach AWS Secrets Manager / SSM endpoints"
}
```

**Escalation Triggers:**
- Private subnet free IPs < 30 per AZ → alert `cluster-agent` (Karpenter may fail to launch nodes)
- NAT gateway in an AZ reported unhealthy → failover assessment, alert `infra-agent`
- Security group rule count approaching 60 → refactor using prefix lists

---

### `iam-agent`

**Purpose:** Manages all IAM roles, policies, and IRSA bindings. Enforces least-privilege access for both human operators and EKS workloads.

**Responsibilities:**
- Terraform-managed IAM roles and policies (no manual console changes)
- IRSA configuration via OIDC provider on EKS for workload identity
- AWS SSO permission sets for human operator access tiers
- Workload access to AWS Secrets Manager via IRSA (no static credentials)
- Periodic access reviews: flag roles unused for 90+ days

**IRSA Pattern (Workload → Secrets Manager):**
```hcl
module "irsa_app" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "app-role-prod"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["default:app-sa"]
    }
  }

  role_policy_arns = {
    secrets = aws_iam_policy.app_secrets.arn
  }
}

resource "aws_iam_policy" "app_secrets" {
  name = "app-secrets-manager-read"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
      Resource = "arn:aws:secretsmanager:eu-west-1:123456789012:secret:prod/app/*"
    }]
  })
}
```

**Kubernetes Service Account:**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
  namespace: default
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/app-role-prod
```

**Secrets Manager Access Pattern:**
All workloads retrieve secrets at runtime via the AWS SDK using IRSA — no secrets stored in Kubernetes Secrets, environment variables, or config files.

```python
import boto3

client = boto3.client("secretsmanager", region_name="eu-west-1")
secret = client.get_secret_value(SecretId="prod/app/database")
```

Alternatively, the **AWS Secrets Store CSI Driver** can sync Secrets Manager values into pod-mounted volumes:
```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: app-secrets
spec:
  provider: aws
  parameters:
    objects: |
      - objectName: "prod/app/database"
        objectType: "secretsmanager"
```

**Access Tiers:**

| Tier | Principals | Permissions |
|---|---|---|
| Read-only | All engineers | `describe`, `list`, `get` across all services |
| Operator | Senior DevOps | Read + targeted write; no IAM modifications |
| Break-glass | On-call lead | Temporary `AdministratorAccess`, 4-hour session TTL |
| CI/CD | GitHub Actions (OIDC) | Scoped to `terraform plan` / `apply` on target accounts |

**GitHub Actions OIDC (no static keys):**
```hcl
module "github_oidc" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-github-oidc-role"
  version = "~> 5.0"

  name = "github-actions-terraform"
  subjects = ["repo:my-org/infra:ref:refs/heads/main"]

  policies = {
    terraform = aws_iam_policy.terraform_deploy.arn
  }
}
```

**Escalation Triggers:**
- `AccessDenied` on a critical deployment path → immediate operator review
- Wildcard `*` resource detected in a new policy → block PR merge, alert team
- IAM role not used in 90 days → open deprecation issue
- IRSA binding references a deleted service account → alert `cluster-agent`

---

## Secrets Management

All secrets are stored and accessed via **AWS Secrets Manager**. No secrets are committed to Git, stored in Kubernetes Secrets unencrypted, or passed as plain environment variables.

**Access method by workload type:**

| Workload | Access Method |
|---|---|
| EKS pods | IRSA role → AWS SDK or Secrets Store CSI Driver |
| GitHub Actions | OIDC role → `aws secretsmanager get-secret-value` in workflow |
| Terraform | `aws_secretsmanager_secret_version` data source (read-only) |
| Humans | AWS SSO console or `aws secretsmanager get-secret-value` via CLI |

**Naming convention:**
```
<environment>/<service>/<secret-name>
e.g.  prod/cluster/kubeconfig-token
      prod/app/database-credentials
      dev/app/third-party-api-key
```

---

## Inter-Agent Communication

| Channel | Purpose |
|---|---|
| GitHub PRs | All Terraform changes — plan output must be posted as PR comment |
| `#infra-changes` (Slack) | Automated Terraform plan/apply notifications |
| `#devops-alerts` (Slack) | Escalation alerts from all agents |
| PagerDuty | Production incidents requiring immediate human response |

---

## Runbook Index

| Runbook | Owner Agent |
|---|---|
| `terraform-state-lock.md` | `infra-agent` |
| `eks-control-plane-upgrade.md` | `cluster-agent` |
| `karpenter-node-launch-failure.md` | `cluster-agent` |
| `subnet-ip-exhaustion.md` | `network-agent` |
| `irsa-access-denied.md` | `iam-agent` |
| `secrets-manager-rotation-failure.md` | `iam-agent` |

---

## Versioning

Update this file alongside any significant platform architecture changes. Version history is maintained in Git.

**Last updated:** 2026-05-29
**Maintained by:** Platform Engineering