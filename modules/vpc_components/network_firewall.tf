resource "aws_networkfirewall_rule_group" "allow_all" {
  capacity = 100
  name     = "${var.name}-allow-all"
  type     = "STATEFUL"

  rule_group {
    rules_source {
      rules_string = "pass ip any any -> any any (sid:1; rev:1;)"
    }
  }

  tags = {
    Name = "${var.name}-allow-all"
  }
}

resource "aws_networkfirewall_firewall_policy" "this" {
  name = "${var.name}-firewall-policy"

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]

    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.allow_all.arn
    }
  }

  tags = {
    Name = "${var.name}-firewall-policy"
  }
}

resource "aws_networkfirewall_firewall" "this" {
  name                = "${var.name}-firewall"
  firewall_policy_arn = aws_networkfirewall_firewall_policy.this.arn
  vpc_id              = aws_vpc.this.id

  dynamic "subnet_mapping" {
    for_each = aws_subnet.firewall

    content {
      subnet_id = subnet_mapping.value.id
    }
  }

  tags = {
    Name = "${var.name}-firewall"
  }
}
