resource "aws_vpc" "cloudlake_data_vpc" {
  cidr_block           = "10.1.0.0/24"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-data-vpc-${var.environment}"
    }
  )
}

resource "aws_subnet" "public_data_az1" {
  vpc_id                  = aws_vpc.cloudlake_data_vpc.id
  cidr_block              = "10.1.0.0/25"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags                    = merge(var.tags, { Name = "${var.project_name}-data-public-az1" })
}

resource "aws_subnet" "private_subnet_data_az2" {
  vpc_id                  = aws_vpc.cloudlake_data_vpc.id
  cidr_block              = "10.1.0.128/25"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = false
  tags                    = var.tags
}

# Internet Gateway for data VPC
resource "aws_internet_gateway" "data_igw" {
  vpc_id = aws_vpc.cloudlake_data_vpc.id
  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-data-igw-${var.environment}"
    }
  )
}

# Public Route Table for data VPC
resource "aws_route_table" "public_data_rt" {
  vpc_id = aws_vpc.cloudlake_data_vpc.id
  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-public-data-rt-${var.environment}"
    }
  )
}

# Route to Internet via IGW
resource "aws_route" "public_data_internet_route" {
  route_table_id         = aws_route_table.public_data_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.data_igw.id
}

# Private Route Table for data VPC
resource "aws_route_table" "private_data_rt" {
  vpc_id = aws_vpc.cloudlake_data_vpc.id
  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-private-data-rt-${var.environment}"
    }
  )
}

# Associate private subnets with private route table
resource "aws_route_table_association" "public_data_az1_assoc" {
  subnet_id      = aws_subnet.public_data_az1.id
  route_table_id = aws_route_table.public_data_rt.id
}

resource "aws_route_table_association" "private_data_az2_assoc" {
  subnet_id      = aws_subnet.private_subnet_data_az2.id
  route_table_id = aws_route_table.private_data_rt.id
}

# NAT Gateway for data VPC
resource "aws_eip" "nat_data_eip" {
  domain = "vpc"
  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-data-nat-eip-${var.environment}"
    }
  )
}

resource "aws_nat_gateway" "nat_data_gw" {
  allocation_id = aws_eip.nat_data_eip.id
  subnet_id     = aws_subnet.public_data_az1.id
  tags          = merge(var.tags, { Name = "${var.project_name}-data-nat-gw-${var.environment}" })
}

resource "aws_route" "private_data_internet_route" {
  route_table_id         = aws_route_table.private_data_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_data_gw.id
}