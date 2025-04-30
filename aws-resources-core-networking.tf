resource "aws_vpc" "cloudlake_core" {
  cidr_block           = "10.0.5.0/24"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-core-vpc-${var.environment}"
    }
  )
}

resource "aws_vpc_dhcp_options" "cloudlake_dhcp" {
  domain_name         = "ec2.internal"
  domain_name_servers = ["AmazonProvidedDNS"]

  tags = var.tags
}

resource "aws_vpc_dhcp_options_association" "cloudlake_dhcp_assoc" {
  vpc_id          = aws_vpc.cloudlake_core.id
  dhcp_options_id = aws_vpc_dhcp_options.cloudlake_dhcp.id
}

data "aws_availability_zones" "available" {}

resource "aws_subnet" "private_core_az1" {
  vpc_id                  = aws_vpc.cloudlake_core.id
  cidr_block              = "10.0.5.0/26"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false
  tags                    = var.tags
}

resource "aws_subnet" "private_core_az2" {
  vpc_id            = aws_vpc.cloudlake_core.id
  cidr_block        = "10.0.5.64/26"
  availability_zone = data.aws_availability_zones.available.names[1]
  tags              = { Name = "${var.project_name}-private-subnet-az2" }
}

resource "aws_subnet" "private_core_az3" {
  vpc_id                  = aws_vpc.cloudlake_core.id
  cidr_block              = "10.0.5.128/26"
  availability_zone       = data.aws_availability_zones.available.names[2]
  map_public_ip_on_launch = false
  tags                    = { Name = "${var.project_name}-private-subnet-az3" }
}

#to define explicit routing
resource "aws_route_table" "private_core_rt" {
  vpc_id = aws_vpc.cloudlake_core.id

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-private-rt-${var.environment}"
    }
  )
}

resource "aws_route_table_association" "private_az1_core_assoc" {
  subnet_id      = aws_subnet.private_core_az1.id
  route_table_id = aws_route_table.private_core_rt.id
}

resource "aws_route_table_association" "private_az2_core_assoc" {
  subnet_id      = aws_subnet.private_core_az2.id
  route_table_id = aws_route_table.private_core_rt.id
}

# VPC Endpoint (Interface Type for MSK)
resource "aws_vpc_endpoint" "cloudlake_msk_interface" {
  vpc_id             = aws_vpc.cloudlake_core.id
  service_name       = "com.amazonaws.${var.aws_region}.kafka"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = [aws_subnet.private_core_az1.id, aws_subnet.private_core_az2.id]
  security_group_ids = [aws_security_group.msk_sg.id]

  private_dns_enabled = false

  tags = var.tags
}


#EC2 network configuration

# Add a public subnet for NAT Gateway
resource "aws_subnet" "public_core_az1" {
  vpc_id                  = aws_vpc.cloudlake_core.id
  cidr_block              = "10.0.5.192/26"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-public-subnet-az1-${var.environment}"
    }
  )
}

# Internet Gateway
resource "aws_internet_gateway" "core_igw" {
  vpc_id = aws_vpc.cloudlake_core.id

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-igw-${var.environment}"
    }
  )
}

# Public Route Table
resource "aws_route_table" "public_core_rt" {
  vpc_id = aws_vpc.cloudlake_core.id

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-public-rt-${var.environment}"
    }
  )
}

# Route to Internet via IGW
resource "aws_route" "public_core_internet_route" {
  route_table_id         = aws_route_table.private_core_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.core_igw.id
}

# Associate public subnet with public route table
resource "aws_route_table_association" "public_az1_core_assoc" {
  subnet_id      = aws_subnet.private_core_az1.id
  route_table_id = aws_route_table.private_core_rt.id
}

# NAT Gateway
resource "aws_eip" "nat_core_eip" {
  domain = "vpc"

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-nat-eip-${var.environment}"
    }
  )
}

resource "aws_nat_gateway" "nat_core_gw" {
  allocation_id = aws_eip.nat_core_eip.id
  subnet_id     = aws_subnet.public_core_az1.id

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-nat-gw-${var.environment}"
    }
  )
}

