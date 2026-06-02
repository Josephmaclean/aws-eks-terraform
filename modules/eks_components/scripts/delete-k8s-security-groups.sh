#!/usr/bin/env bash
set -euo pipefail

aws_ec2() {
  aws --region "$AWS_REGION" --profile "$AWS_PROFILE" ec2 "$@"
}

k8s_security_groups() {
  aws_ec2 describe-security-groups \
    --filters Name=vpc-id,Values="$VPC_ID" \
    --query "SecurityGroups[?GroupName!='default' && starts_with(GroupName, 'k8s-')].GroupId" \
    --output text
}

for tag_key in karpenter.sh/nodepool karpenter.sh/nodeclaim karpenter.k8s.aws/ec2nodeclass; do
  INSTANCE_IDS=$(aws_ec2 describe-instances --filters Name=vpc-id,Values="$VPC_ID" Name=tag-key,Values="$tag_key" Name=instance-state-name,Values=pending,running,stopping,stopped --query 'Reservations[].Instances[].InstanceId' --output text)
  if [ -n "$INSTANCE_IDS" ]; then
    aws_ec2 terminate-instances --instance-ids $INSTANCE_IDS >/dev/null
    aws_ec2 wait instance-terminated --instance-ids $INSTANCE_IDS
  fi
done

for attempt in $(seq 1 60); do
  KARPENTER_ENI_COUNT=$(aws_ec2 describe-network-interfaces --filters Name=vpc-id,Values="$VPC_ID" Name=tag:eks:eni:owner,Values=amazon-vpc-cni --query "length(NetworkInterfaces[?TagSet[?Key=='karpenter.sh/nodepool'] || starts_with(Description, 'aws-K8S-')])" --output text)
  if [ "$KARPENTER_ENI_COUNT" = "0" ]; then
    break
  fi

  echo "waiting for Karpenter network interfaces to clear: $KARPENTER_ENI_COUNT"
  sleep 10
done

for group_id in $(k8s_security_groups); do
  REFERENCING_GROUP_IDS=$(aws_ec2 describe-security-groups --filters Name=vpc-id,Values="$VPC_ID" Name=ip-permission.group-id,Values="$group_id" --query "SecurityGroups[].GroupId" --output text)
  for referencing_group_id in $REFERENCING_GROUP_IDS; do
    IP_PERMISSIONS=$(aws_ec2 describe-security-groups --group-ids "$referencing_group_id" --query "SecurityGroups[0].IpPermissions[?UserIdGroupPairs[?GroupId=='$group_id']]" --output json)
    if [ "$IP_PERMISSIONS" = "[]" ]; then
      continue
    fi

    permissions_file=$(mktemp)
    printf '%s\n' "$IP_PERMISSIONS" >"$permissions_file"
    aws_ec2 revoke-security-group-ingress --group-id "$referencing_group_id" --ip-permissions "file://$permissions_file" || true
    rm -f "$permissions_file"
  done
done

for attempt in $(seq 1 12); do
  SG_IDS=$(k8s_security_groups)
  if [ -z "$SG_IDS" ]; then
    break
  fi

  for group_id in $SG_IDS; do
    aws_ec2 delete-security-group --group-id "$group_id" || true
  done
  sleep 10
done
