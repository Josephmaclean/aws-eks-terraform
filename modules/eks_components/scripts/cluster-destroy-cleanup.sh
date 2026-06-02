#!/usr/bin/env bash
set -euo pipefail

aws_elb() { aws --region "$AWS_REGION" --profile "$AWS_PROFILE" elb "$@"; }
aws_elbv2() { aws --region "$AWS_REGION" --profile "$AWS_PROFILE" elbv2 "$@"; }
aws_ec2() { aws --region "$AWS_REGION" --profile "$AWS_PROFILE" ec2 "$@"; }

ELBV2_ARNS=$(aws_elbv2 describe-load-balancers --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" --output text)
for arn in $ELBV2_ARNS; do
  aws_elbv2 delete-load-balancer --load-balancer-arn "$arn" || true
done

CLASSIC_NAMES=$(aws_elb describe-load-balancers --query "LoadBalancerDescriptions[?VPCId=='$VPC_ID'].LoadBalancerName" --output text)
for name in $CLASSIC_NAMES; do
  aws_elb delete-load-balancer --load-balancer-name "$name" || true
done

for attempt in $(seq 1 60); do
  ELB_ENI_COUNT=$(aws_ec2 describe-network-interfaces --filters Name=vpc-id,Values="$VPC_ID" --query "length(NetworkInterfaces[?starts_with(Description, 'ELB ')])" --output text)
  if [ "$ELB_ENI_COUNT" = "0" ]; then
    break
  fi
  echo "waiting for Kubernetes load balancer network interfaces to clear: $ELB_ENI_COUNT"
  sleep 10
done

/bin/bash "$(dirname "$0")/delete-k8s-security-groups.sh"
