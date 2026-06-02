resource "aws_security_group" "nodes" {
  name                   = "${var.cluster_name}-nodes"
  description            = "Security group selected by EKS and Karpenter nodes"
  revoke_rules_on_delete = true
  vpc_id                 = var.vpc_id

  tags = merge(local.karpenter_discovery_tags, {
    Name                  = "${var.cluster_name}-nodes"
    "cleanup.aws_profile" = var.aws_profile
    "cleanup.aws_region"  = var.aws_region
  })

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail

      group_id='${self.id}'
      group_arn='${self.arn}'
      region='${lookup(self.tags, "cleanup.aws_region", "")}'
      profile='${lookup(self.tags, "cleanup.aws_profile", "")}'

      if [ -z "$region" ]; then
        region=$(printf '%s\n' "$group_arn" | cut -d: -f4)
      fi

      aws_ec2() {
        if [ -n "$profile" ]; then
          aws --region "$region" --profile "$profile" ec2 "$@"
        else
          aws --region "$region" ec2 "$@"
        fi
      }

      attached_instance_ids() {
        aws_ec2 describe-network-interfaces \
          --filters Name=group-id,Values="$group_id" \
          --query 'NetworkInterfaces[?Attachment.InstanceId!=null].Attachment.InstanceId' \
          --output text |
          tr '\t' '\n' |
          sed '/^$/d' |
          sort -u
      }

      remaining_network_interfaces() {
        aws_ec2 describe-network-interfaces \
          --filters Name=group-id,Values="$group_id" \
          --query 'NetworkInterfaces[].NetworkInterfaceId' \
          --output text |
          tr '\t' '\n' |
          sed '/^$/d' |
          sort -u
      }

      delete_available_network_interfaces() {
        local eni_ids
        eni_ids=$(aws_ec2 describe-network-interfaces \
          --filters Name=group-id,Values="$group_id" Name=status,Values=available \
          --query 'NetworkInterfaces[].NetworkInterfaceId' \
          --output text)

        for eni_id in $eni_ids; do
          echo "deleting available network interface $eni_id attached to $group_id"
          aws_ec2 delete-network-interface --network-interface-id "$eni_id" || true
        done
      }

      for attempt in $(seq 1 3); do
        instance_ids=$(attached_instance_ids)
        if [ -z "$instance_ids" ]; then
          break
        fi

        echo "terminating instances still attached to $group_id: $instance_ids"
        aws_ec2 terminate-instances --instance-ids $instance_ids >/dev/null || true
        aws_ec2 wait instance-terminated --instance-ids $instance_ids || true
      done

      for attempt in $(seq 1 60); do
        delete_available_network_interfaces
        eni_ids=$(remaining_network_interfaces)
        if [ -z "$eni_ids" ]; then
          exit 0
        fi

        echo "waiting for network interfaces to detach from $group_id: $eni_ids"
        sleep 10
      done

      echo "network interfaces still depend on $group_id:" >&2
      aws_ec2 describe-network-interfaces \
        --filters Name=group-id,Values="$group_id" \
        --query 'NetworkInterfaces[].{NetworkInterfaceId:NetworkInterfaceId,Status:Status,SubnetId:SubnetId,Description:Description,AttachmentInstanceId:Attachment.InstanceId}' \
        --output table >&2 || true
      exit 1
    EOT
  }
}

resource "aws_security_group_rule" "nodes_egress_all" {
  type              = "egress"
  security_group_id = aws_security_group.nodes.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "nodes_ingress_self" {
  type                     = "ingress"
  security_group_id        = aws_security_group.nodes.id
  source_security_group_id = aws_security_group.nodes.id
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
}
