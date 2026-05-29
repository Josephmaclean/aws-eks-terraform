resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.key
  map_public_ip_on_launch = true

  tags = {
    Name                     = each.value.name
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "firewall" {
  for_each = local.firewall_subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.key

  tags = {
    Name = each.value.name
  }
}

resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.key

  tags = merge({
    Name                              = each.value.name
    "kubernetes.io/role/internal-elb" = "1"
    }, var.karpenter_discovery != "" ? {
    "karpenter.sh/discovery" = var.karpenter_discovery
  } : {})
}
