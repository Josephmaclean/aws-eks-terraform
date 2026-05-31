#!/usr/bin/env bash
set -euo pipefail

for attempt in $(seq 1 12); do
  SG_IDS=$(aws ec2 describe-security-groups --region "$AWS_REGION" --profile "$AWS_PROFILE" --filters Name=vpc-id,Values="$VPC_ID" --query "SecurityGroups[?GroupName!='default' && starts_with(GroupName, 'k8s-')].GroupId" --output text)
  if [ -z "$SG_IDS" ]; then
    break
  fi
  for group_id in $SG_IDS; do
    aws ec2 delete-security-group --region "$AWS_REGION" --profile "$AWS_PROFILE" --group-id "$group_id" || true
  done
  sleep 10
done
