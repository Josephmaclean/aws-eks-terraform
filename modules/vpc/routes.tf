resource "aws_route_table" "internet_gateway" {
  vpc_id = aws_vpc.this.id

  dynamic "route" {
    for_each = aws_subnet.public

    content {
      cidr_block      = route.value.cidr_block
      vpc_endpoint_id = local.firewall_endpoint_ids[route.value.availability_zone]
    }
  }

  tags = {
    Name = "${var.name}-igw-rt"
  }
}

resource "aws_route_table_association" "internet_gateway" {
  gateway_id     = aws_internet_gateway.this.id
  route_table_id = aws_route_table.internet_gateway.id
}

resource "aws_route_table" "public" {
  for_each = aws_subnet.public

  vpc_id = aws_vpc.this.id

  route {
    cidr_block      = "0.0.0.0/0"
    vpc_endpoint_id = local.firewall_endpoint_ids[each.value.availability_zone]
  }

  tags = {
    Name = "${var.name}-public-${each.key}-rt"
  }
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public[each.key].id
}

resource "aws_route_table" "firewall" {
  for_each = aws_subnet.firewall

  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.name}-firewall-${each.key}-rt"
  }
}

resource "aws_route_table_association" "firewall" {
  for_each = aws_subnet.firewall

  subnet_id      = each.value.id
  route_table_id = aws_route_table.firewall[each.key].id
}

resource "aws_route_table" "private" {
  for_each = aws_subnet.private

  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = {
    Name = "${var.name}-private-${each.key}-rt"
  }
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}
