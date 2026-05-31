#!/usr/bin/env bash
set -euo pipefail

for attempt in $(seq 1 60); do
  ELBV2_ARNS=$(aws elbv2 describe-load-balancers --region "$AWS_REGION" --profile "$AWS_PROFILE" --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" --output text)
  CLASSIC_NAMES=$(aws elb describe-load-balancers --region "$AWS_REGION" --profile "$AWS_PROFILE" --query "LoadBalancerDescriptions[?VPCId=='$VPC_ID'].LoadBalancerName" --output text)
  if [ -z "$ELBV2_ARNS" ] && [ -z "$CLASSIC_NAMES" ]; then
    break
  fi
  echo "waiting for Kubernetes load balancers to clear"
  sleep 10
done

for arn in $ELBV2_ARNS; do
  aws elbv2 delete-load-balancer --region "$AWS_REGION" --profile "$AWS_PROFILE" --load-balancer-arn "$arn" || true
done
for name in $CLASSIC_NAMES; do
  aws elb delete-load-balancer --region "$AWS_REGION" --profile "$AWS_PROFILE" --load-balancer-name "$name" || true
done

KARPENTER_INSTANCES=$(aws ec2 describe-instances --region "$AWS_REGION" --profile "$AWS_PROFILE" --filters Name=vpc-id,Values="$VPC_ID" Name=tag-key,Values=karpenter.sh/nodepool Name=instance-state-name,Values=pending,running,stopping,stopped --query 'Reservations[].Instances[].InstanceId' --output text)
if [ -n "$KARPENTER_INSTANCES" ]; then
  aws ec2 terminate-instances --region "$AWS_REGION" --profile "$AWS_PROFILE" --instance-ids $KARPENTER_INSTANCES >/dev/null
  aws ec2 wait instance-terminated --region "$AWS_REGION" --profile "$AWS_PROFILE" --instance-ids $KARPENTER_INSTANCES
fi

for attempt in $(seq 1 60); do
  ELB_ENI_COUNT=$(aws ec2 describe-network-interfaces --region "$AWS_REGION" --profile "$AWS_PROFILE" --filters Name=vpc-id,Values="$VPC_ID" --query "length(NetworkInterfaces[?starts_with(Description, 'ELB ')])" --output text)
  if [ "$ELB_ENI_COUNT" = "0" ]; then
    break
  fi
  echo "waiting for Kubernetes load balancer network interfaces to clear: $ELB_ENI_COUNT"
  sleep 10
done

/bin/bash "$(dirname "$0")/delete-k8s-security-groups.sh"
