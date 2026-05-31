# EKS

This module creates:

- Private EKS control plane endpoint by default
- EKS managed node group `primary` for regular workloads
- EKS managed node group `ml` for GPU/ML workloads
- Core EKS add-ons: VPC CNI, kube-proxy, CoreDNS, EKS Pod Identity Agent
- IAM roles for managed nodes, Karpenter controller, and Karpenter-launched nodes
- Karpenter interruption SQS queue and EventBridge forwarding
- Pod Identity association for the Karpenter controller service account

## Karpenter

Terraform prepares AWS-side Karpenter permissions, but it does not install the Karpenter controller into the cluster. Install Karpenter with Helm after the cluster exists, using the module outputs:

```sh
terraform output karpenter_controller_role_arn
terraform output karpenter_interruption_queue_name
terraform output karpenter_node_role_name
```

Example Karpenter `NodePool` and `EC2NodeClass` manifests live in `modules/eks_components/karpenter/`.

The examples use `private-eks` as the cluster/discovery name. If you change `cluster_name`, update the `karpenter.sh/discovery` tag values and node role in those manifests.
