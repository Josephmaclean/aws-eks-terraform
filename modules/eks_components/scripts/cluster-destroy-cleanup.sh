#!/usr/bin/env bash
set -euo pipefail

aws_elb() { aws --region "$AWS_REGION" --profile "$AWS_PROFILE" elb "$@"; }
aws_elbv2() { aws --region "$AWS_REGION" --profile "$AWS_PROFILE" elbv2 "$@"; }
aws_ec2() { aws --region "$AWS_REGION" --profile "$AWS_PROFILE" ec2 "$@"; }
aws_ssm() { aws --region "$AWS_REGION" --profile "$AWS_PROFILE" ssm "$@"; }

print_ssm_command_invocation() {
  local command_id="$1"
  aws_ssm get-command-invocation \
    --command-id "$command_id" \
    --instance-id "$BASTION_INSTANCE_ID" \
    --query '{Status:Status,StandardOutputContent:StandardOutputContent,StandardErrorContent:StandardErrorContent}' \
    --output text || true
}

wait_for_ssm_command() {
  local command_id="$1"
  local status

  for attempt in $(seq 1 120); do
    status=$(aws_ssm get-command-invocation \
      --command-id "$command_id" \
      --instance-id "$BASTION_INSTANCE_ID" \
      --query Status \
      --output text 2>/dev/null || true)

    case "$status" in
      Success)
        return 0
        ;;
      Failed | Cancelled | TimedOut | Cancelling)
        return 1
        ;;
    esac

    sleep 5
  done

  return 1
}

run_bastion_kubernetes_cleanup() {
  if [ -z "${BASTION_INSTANCE_ID:-}" ] || [ -z "${CLUSTER_NAME:-}" ]; then
    echo "skipping bastion Kubernetes cleanup because BASTION_INSTANCE_ID or CLUSTER_NAME is unset"
    return
  fi

  echo "quiescing Kubernetes controllers on bastion instance $BASTION_INSTANCE_ID"
  local parameters
  parameters=$(printf 'commands=["set -euo pipefail","export KUBECONFIG=/root/.kube/config","mkdir -p /root/.kube","aws eks update-kubeconfig --region %s --name %s","kubectl delete nodepools.karpenter.sh --all --ignore-not-found --wait=false || true","kubectl delete nodeclaims.karpenter.sh --all --ignore-not-found --wait=false || true","kubectl -n karpenter scale deployment/karpenter --replicas=0 --timeout=60s || true","helm -n karpenter uninstall karpenter --wait --timeout 5m || true","kubectl -n kube-system scale deployment/aws-load-balancer-controller --replicas=0 --timeout=60s || true"]' "$AWS_REGION" "$CLUSTER_NAME")

  local command_id
  if ! command_id=$(aws_ssm send-command \
    --document-name AWS-RunShellScript \
    --instance-ids "$BASTION_INSTANCE_ID" \
    --parameters "$parameters" \
    --query "Command.CommandId" \
    --output text); then
    echo "failed to start bastion Kubernetes cleanup; continuing with AWS-side cleanup"
    return
  fi

  if ! wait_for_ssm_command "$command_id"; then
    echo "bastion Kubernetes cleanup command did not complete cleanly; command output follows"
    print_ssm_command_invocation "$command_id"
  fi
}

elb_network_interface_count() {
  aws_ec2 describe-network-interfaces \
    --filters Name=vpc-id,Values="$VPC_ID" \
    --query "length(NetworkInterfaces[?starts_with(Description, 'ELB ')])" \
    --output text
}

wait_for_elb_network_interfaces() {
  local elb_eni_count
  for attempt in $(seq 1 60); do
    elb_eni_count=$(elb_network_interface_count)
    if [ "$elb_eni_count" = "0" ]; then
      return
    fi
    echo "waiting for Kubernetes load balancer network interfaces to clear: $elb_eni_count"
    sleep 10
  done

  elb_eni_count=$(elb_network_interface_count)
  if [ "$elb_eni_count" != "0" ]; then
    echo "load balancer network interfaces still exist after waiting: $elb_eni_count" >&2
    exit 1
  fi
}

run_bastion_kubernetes_cleanup

ELBV2_ARNS=$(aws_elbv2 describe-load-balancers --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" --output text)
for arn in $ELBV2_ARNS; do
  aws_elbv2 delete-load-balancer --load-balancer-arn "$arn" || true
done

CLASSIC_NAMES=$(aws_elb describe-load-balancers --query "LoadBalancerDescriptions[?VPCId=='$VPC_ID'].LoadBalancerName" --output text)
for name in $CLASSIC_NAMES; do
  aws_elb delete-load-balancer --load-balancer-name "$name" || true
done

wait_for_elb_network_interfaces

/bin/bash "$(dirname "$0")/delete-k8s-security-groups.sh"
