#!/usr/bin/env bash
set -euo pipefail

aws_ec2() {
  aws --region "$AWS_REGION" --profile "$AWS_PROFILE" ec2 "$@"
}

normalize_ids() {
  tr '\t' '\n' | sed '/^$/d' | sort -u
}

k8s_security_groups() {
  aws_ec2 describe-security-groups \
    --filters Name=vpc-id,Values="$VPC_ID" \
    --query "SecurityGroups[?GroupName!='default' && starts_with(GroupName, 'k8s-')].GroupId" \
    --output text
}

security_groups_for_reference_cleanup() {
  {
    k8s_security_groups
    if [ -n "${CLUSTER_NAME:-}" ]; then
      aws_ec2 describe-security-groups \
        --filters Name=vpc-id,Values="$VPC_ID" Name=tag:karpenter.sh/discovery,Values="$CLUSTER_NAME" \
        --query "SecurityGroups[?GroupName!='default'].GroupId" \
        --output text
      aws_ec2 describe-security-groups \
        --filters Name=vpc-id,Values="$VPC_ID" Name=tag-key,Values="kubernetes.io/cluster/$CLUSTER_NAME" \
        --query "SecurityGroups[?GroupName!='default'].GroupId" \
        --output text
    fi
  } | normalize_ids
}

karpenter_instance_ids_from_instance_tags() {
  for tag_key in karpenter.sh/nodepool karpenter.sh/nodeclaim karpenter.k8s.aws/ec2nodeclass; do
    aws_ec2 describe-instances \
      --filters Name=vpc-id,Values="$VPC_ID" Name=tag-key,Values="$tag_key" Name=instance-state-name,Values=pending,running,stopping,stopped \
      --query 'Reservations[].Instances[].InstanceId' \
      --output text
  done
}

karpenter_instance_ids_from_network_interfaces() {
  for tag_key in karpenter.sh/nodepool karpenter.sh/nodeclaim karpenter.k8s.aws/ec2nodeclass; do
    aws_ec2 describe-network-interfaces \
      --filters Name=vpc-id,Values="$VPC_ID" Name=tag-key,Values="$tag_key" \
      --query 'NetworkInterfaces[?Attachment.InstanceId!=null].Attachment.InstanceId' \
      --output text
  done
}

karpenter_instance_ids() {
  {
    karpenter_instance_ids_from_instance_tags
    karpenter_instance_ids_from_network_interfaces
  } | normalize_ids
}

karpenter_network_interface_ids() {
  for tag_key in karpenter.sh/nodepool karpenter.sh/nodeclaim karpenter.k8s.aws/ec2nodeclass; do
    aws_ec2 describe-network-interfaces \
      --filters Name=vpc-id,Values="$VPC_ID" Name=tag-key,Values="$tag_key" \
      --query 'NetworkInterfaces[].NetworkInterfaceId' \
      --output text
  done | normalize_ids
}

delete_available_kubernetes_network_interfaces() {
  local eni_ids
  eni_ids=$(
    {
      aws_ec2 describe-network-interfaces \
        --filters Name=vpc-id,Values="$VPC_ID" Name=status,Values=available Name=tag:eks:eni:owner,Values=amazon-vpc-cni \
        --query 'NetworkInterfaces[].NetworkInterfaceId' \
        --output text
      for tag_key in karpenter.sh/nodepool karpenter.sh/nodeclaim karpenter.k8s.aws/ec2nodeclass; do
        aws_ec2 describe-network-interfaces \
          --filters Name=vpc-id,Values="$VPC_ID" Name=status,Values=available Name=tag-key,Values="$tag_key" \
          --query 'NetworkInterfaces[].NetworkInterfaceId' \
          --output text
      done
    } | normalize_ids
  )

  for eni_id in $eni_ids; do
    echo "deleting available Kubernetes network interface $eni_id"
    aws_ec2 delete-network-interface --network-interface-id "$eni_id" || true
  done
}

terminate_karpenter_instances() {
  local instance_ids
  for attempt in $(seq 1 3); do
    instance_ids=$(karpenter_instance_ids)
    if [ -z "$instance_ids" ]; then
      return
    fi

    echo "terminating Karpenter instances: $instance_ids"
    aws_ec2 terminate-instances --instance-ids $instance_ids >/dev/null || true
    aws_ec2 wait instance-terminated --instance-ids $instance_ids || true
  done

  instance_ids=$(karpenter_instance_ids)
  if [ -n "$instance_ids" ]; then
    echo "Karpenter instances remain after cleanup: $instance_ids" >&2
    exit 1
  fi
}

wait_for_karpenter_network_interfaces() {
  local eni_ids
  for attempt in $(seq 1 60); do
    delete_available_kubernetes_network_interfaces
    eni_ids=$(karpenter_network_interface_ids)
    if [ -z "$eni_ids" ]; then
      return
    fi

    echo "waiting for Karpenter network interfaces to clear: $eni_ids"
    sleep 10
  done

  eni_ids=$(karpenter_network_interface_ids)
  if [ -n "$eni_ids" ]; then
    echo "Karpenter network interfaces remain after cleanup: $eni_ids" >&2
    exit 1
  fi
}

revoke_matching_security_group_permissions() {
  local group_id="$1"
  local filter_name="$2"
  local permission_field="$3"
  local revoke_command="$4"
  local referencing_group_ids

  referencing_group_ids=$(aws_ec2 describe-security-groups \
    --filters Name=vpc-id,Values="$VPC_ID" Name="$filter_name",Values="$group_id" \
    --query "SecurityGroups[].GroupId" \
    --output text)

  for referencing_group_id in $referencing_group_ids; do
    local ip_permissions
    local permissions_file
    ip_permissions=$(aws_ec2 describe-security-groups \
      --group-ids "$referencing_group_id" \
      --query "SecurityGroups[0].$permission_field[?UserIdGroupPairs[?GroupId=='$group_id']]" \
      --output json)
    if [ "$ip_permissions" = "[]" ]; then
      continue
    fi

    permissions_file=$(mktemp)
    printf '%s\n' "$ip_permissions" >"$permissions_file"
    aws_ec2 "$revoke_command" --group-id "$referencing_group_id" --ip-permissions "file://$permissions_file" || true
    rm -f "$permissions_file"
  done
}

revoke_security_group_references() {
  local group_id
  for group_id in $(security_groups_for_reference_cleanup); do
    revoke_matching_security_group_permissions "$group_id" ip-permission.group-id IpPermissions revoke-security-group-ingress
    revoke_matching_security_group_permissions "$group_id" egress.ip-permission.group-id IpPermissionsEgress revoke-security-group-egress
  done
}

diagnose_security_group_blockers() {
  local group_id="$1"
  echo "remaining blockers for security group $group_id:" >&2
  aws_ec2 describe-network-interfaces \
    --filters Name=group-id,Values="$group_id" \
    --query 'NetworkInterfaces[].{NetworkInterfaceId:NetworkInterfaceId,Status:Status,SubnetId:SubnetId,Description:Description,AttachmentInstanceId:Attachment.InstanceId}' \
    --output table >&2 || true
  aws_ec2 describe-security-groups \
    --filters Name=vpc-id,Values="$VPC_ID" Name=ip-permission.group-id,Values="$group_id" \
    --query 'SecurityGroups[].{GroupId:GroupId,GroupName:GroupName}' \
    --output table >&2 || true
  aws_ec2 describe-security-groups \
    --filters Name=vpc-id,Values="$VPC_ID" Name=egress.ip-permission.group-id,Values="$group_id" \
    --query 'SecurityGroups[].{GroupId:GroupId,GroupName:GroupName}' \
    --output table >&2 || true
}

delete_k8s_security_groups() {
  local sg_ids
  for attempt in $(seq 1 12); do
    revoke_security_group_references
    sg_ids=$(k8s_security_groups)
    if [ -z "$sg_ids" ]; then
      return
    fi

    for group_id in $sg_ids; do
      aws_ec2 delete-security-group --group-id "$group_id" || true
    done
    sleep 10
  done

  sg_ids=$(k8s_security_groups)
  if [ -n "$sg_ids" ]; then
    for group_id in $sg_ids; do
      diagnose_security_group_blockers "$group_id"
    done
    echo "Kubernetes-created security groups remain after cleanup: $sg_ids" >&2
    exit 1
  fi
}

terminate_karpenter_instances
wait_for_karpenter_network_interfaces
delete_k8s_security_groups
