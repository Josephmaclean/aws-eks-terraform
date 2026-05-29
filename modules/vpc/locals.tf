data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  selected_availability_zones = length(var.availability_zones) > 0 ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, 2)

  public_subnets = {
    for index, az in local.selected_availability_zones : az => {
      cidr = var.public_subnet_cidrs[index]
      name = "${var.name}-public-${index + 1}"
    }
  }

  firewall_subnets = {
    for index, az in local.selected_availability_zones : az => {
      cidr = var.firewall_subnet_cidrs[index]
      name = "${var.name}-firewall-${index + 1}"
    }
  }

  private_subnets = {
    for index, az in local.selected_availability_zones : az => {
      cidr = var.private_subnet_cidrs[index]
      name = "${var.name}-private-${index + 1}"
    }
  }

  firewall_endpoint_ids = {
    for sync_state in aws_networkfirewall_firewall.this.firewall_status[0].sync_states :
    sync_state.availability_zone => sync_state.attachment[0].endpoint_id
  }
}
