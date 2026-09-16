# 1. Available Availability Zones Lookup
data "aws_availability_zones" "available" {
  state = "available"
}

# 2. Main VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  lifecycle {
    precondition {
      condition = (
        length(var.public_subnet_cidrs) >= 2 &&
        length(var.public_subnet_cidrs) == length(var.private_subnet_cidrs) &&
        length(var.public_subnet_cidrs) == length(var.database_subnet_cidrs) &&
        length(var.public_subnet_cidrs) <= length(data.aws_availability_zones.available.names)
      )
      error_message = "Use equal subnet counts across all three tiers, at least two, and no more than available AZs."
    }
  }

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# 3. Internet Gateway for Public Tier
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# -----------------------------------------------------------------------------
# TIER 1: PUBLIC SUBNETS (ALB + NAT Gateways)
# -----------------------------------------------------------------------------
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
    Tier = "Public"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# One NAT Gateway per public subnet/AZ keeps private application egress available
# when a single Availability Zone is impaired. NAT Gateways incur hourly/data costs.
resource "aws_eip" "nat" {
  count  = length(var.public_subnet_cidrs)
  domain = "vpc"

  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "${var.project_name}-nat-eip-${count.index + 1}"
  }
}

resource "aws_nat_gateway" "this" {
  count         = length(var.public_subnet_cidrs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "${var.project_name}-nat-${count.index + 1}"
  }
}

# -----------------------------------------------------------------------------
# TIER 2: PRIVATE APPLICATION SUBNETS (EC2 Backend)
# -----------------------------------------------------------------------------
resource "aws_subnet" "private" {
  count                   = length(var.private_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-private-subnet-${count.index + 1}"
    Tier = "Private-App"
  }
}

# Use one private route table per application subnet so each AZ uses its local NAT.
resource "aws_route_table" "private" {
  count  = length(var.private_subnet_cidrs)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[count.index].id
  }

  tags = {
    Name = "${var.project_name}-private-rt-${count.index + 1}"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# -----------------------------------------------------------------------------
# TIER 3: ISOLATED DATABASE SUBNETS (RDS)
# -----------------------------------------------------------------------------
resource "aws_subnet" "database" {
  count                   = length(var.database_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.database_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-db-subnet-${count.index + 1}"
    Tier = "Database-Isolated"
  }
}

resource "aws_db_subnet_group" "main" {
  name        = "${var.project_name}-db-subnet-group"
  description = "Subnet group for isolated RDS database tier"
  subnet_ids  = aws_subnet.database[*].id

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

# No default route is intentionally configured for the database tier.
resource "aws_route_table" "database" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-database-rt"
  }
}

resource "aws_route_table_association" "database" {
  count          = length(var.database_subnet_cidrs)
  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database.id
}
