terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

locals {
  azs             = var.azs
  vpc_cidr        = var.vpc_cidr_block
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]
  db_private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 52)]
}

# VPC
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-vpc"
    }
  )
}

# Internet Gateway
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-igw"
    }
  )
}

# Public Subnets
resource "aws_subnet" "public" {
  count = length(local.public_subnets)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_subnets[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-public-${count.index + 1}"
      Type = "Public"
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
      "kubernetes.io/role/elb" = "1"
    }
  )
}

# Private Subnets
resource "aws_subnet" "private" {
  count = length(local.private_subnets)

  vpc_id            = aws_vpc.this.id
  cidr_block        = local.private_subnets[count.index]
  availability_zone = local.azs[count.index]

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-private-${count.index + 1}"
      Type = "Private"
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
      "kubernetes.io/role/internal-elb" = "1"
    }
  )
}

# Database Private Subnets
resource "aws_subnet" "db_private" {
  count = length(local.db_private_subnets)

  vpc_id            = aws_vpc.this.id
  cidr_block        = local.db_private_subnets[count.index]
  availability_zone = local.azs[count.index]

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-db-private-${count.index + 1}"
      Type = "DB-Private"
    }
  )
}

# NAT Gateways
resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? (var.nat_gateway_mode == "dedicated" ? length(local.public_subnets) : 1) : 0

  domain = "vpc"

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-nat-eip-${count.index + 1}"
    }
  )
}

resource "aws_nat_gateway" "this" {
  count = var.enable_nat_gateway && var.nat_gateway_mode == "dedicated" ? length(local.public_subnets) : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-nat-${count.index + 1}"
    }
  )

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "shared" {
  count = var.enable_nat_gateway && var.nat_gateway_mode == "shared" ? 1 : 0

  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-nat-shared"
    }
  )

  depends_on = [aws_internet_gateway.this]
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-public-rt"
    }
  )
}

resource "aws_route_table" "private" {
  count = var.enable_nat_gateway ? (var.nat_gateway_mode == "dedicated" ? length(local.private_subnets) : 1) : 1

  vpc_id = aws_vpc.this.id

  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block = "0.0.0.0/0"
      nat_gateway_id = var.nat_gateway_mode == "dedicated" ? aws_nat_gateway.this[count.index % length(aws_nat_gateway.this)].id : aws_nat_gateway.shared[0].id
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-private-rt${count.index > 0 ? "-${count.index + 1}" : ""}"
    }
  )
}

resource "aws_route_table" "db_private" {
  vpc_id = aws_vpc.this.id

  # AWS automatically adds the local route for VPC CIDR, no need to specify

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-db-private-rt"
    }
  )
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count = length(local.public_subnets)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count = length(local.private_subnets)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = var.enable_nat_gateway ? aws_route_table.private[count.index % length(aws_route_table.private)].id : aws_route_table.private[0].id
}

resource "aws_route_table_association" "db_private" {
  count = length(local.db_private_subnets)

  subnet_id      = aws_subnet.db_private[count.index].id
  route_table_id = aws_route_table.db_private.id
}

# Security Groups
resource "aws_security_group" "default" {
  name_prefix = "${var.name_prefix}-default-"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.this.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-default-sg"
    }
  )
}

# Network ACLs
resource "aws_network_acl" "public" {
  vpc_id     = aws_vpc.this.id
  subnet_ids = aws_subnet.public[*].id

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-public-nacl"
    }
  )
}

resource "aws_network_acl" "private" {
  vpc_id     = aws_vpc.this.id
  subnet_ids = aws_subnet.private[*].id

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-private-nacl"
    }
  )
}

# Default NACL rules (allow all)
resource "aws_network_acl_rule" "public_ingress" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 100
  egress         = false
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
}

resource "aws_network_acl_rule" "public_egress" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 100
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
}

resource "aws_network_acl_rule" "private_ingress" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 100
  egress         = false
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
}

resource "aws_network_acl_rule" "private_egress" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 100
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
}

# VPC Flow Logs
resource "aws_cloudwatch_log_group" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name              = var.flow_logs_log_group
  retention_in_days = var.flow_logs_retention_days
  kms_key_id        = var.flow_logs_kms_key_id

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-flow-logs"
    }
  )
}

resource "aws_iam_role" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.name_prefix}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  role       = aws_iam_role.flow_logs[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonVPCFlowLogsRole"
}

resource "aws_flow_log" "this" {
  count = var.enable_flow_logs ? 1 : 0

  iam_role_arn    = aws_iam_role.flow_logs[0].arn
  log_destination = aws_cloudwatch_log_group.flow_logs[0].arn
  traffic_type    = var.flow_logs_traffic_type
  vpc_id          = aws_vpc.this.id

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-flow-log"
    }
  )
}

# VPC Endpoints
resource "aws_vpc_endpoint" "this" {
  for_each = var.vpc_endpoints

  vpc_id            = aws_vpc.this.id
  service_name      = each.value.service_name
  vpc_endpoint_type = each.value.type

  security_group_ids = each.value.security_group_ids
  subnet_ids         = each.value.subnet_ids
  route_table_ids    = length(each.value.route_table_ids) > 0 ? each.value.route_table_ids : (
    each.value.type == "Gateway" ? aws_route_table.private[*].id : []
  )

  private_dns_enabled = each.value.type == "Interface" ? each.value.private_dns_enabled : false

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-${each.key}"
    },
    each.value.tags
  )
}
