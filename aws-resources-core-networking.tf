resource "aws_vpc" "cloudlake_core" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = var.tags
}

resource "aws_vpc_dhcp_options" "cloudlake_dhcp" {
  domain_name          = "ec2.internal"
  domain_name_servers  = ["AmazonProvidedDNS"]

  tags = var.tags
}

resource "aws_vpc_dhcp_options_association" "cloudlake_dhcp_assoc" {
  vpc_id          = aws_vpc.cloudlake_core.id
  dhcp_options_id = aws_vpc_dhcp_options.cloudlake_dhcp.id
}

data "aws_availability_zones" "available" {}

resource "aws_subnet" "private_az1" {
  vpc_id                  = aws_vpc.cloudlake_core.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false
  tags = var.tags
}

resource "aws_subnet" "private_az2" {
  vpc_id            = aws_vpc.cloudlake_core.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]
  tags = { Name = "cloudlake-private-subnet-az2" }
}

resource "aws_subnet" "private_az3" {
  vpc_id                  = aws_vpc.cloudlake_core.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = data.aws_availability_zones.available.names[2]
  map_public_ip_on_launch = false
  tags = { Name = "cloudlake-private-subnet-az3" }
}

#to define explicit routing
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.cloudlake_core.id

  tags = {
    Name = "cloudlake-private-rt"
  }
}

resource "aws_route_table_association" "private_az1_assoc" {
  subnet_id      = aws_subnet.private_az1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_az2_assoc" {
  subnet_id      = aws_subnet.private_az2.id
  route_table_id = aws_route_table.private_rt.id
}

# Virtual Private Gateway (VGW)
resource "aws_vpn_gateway" "cloudlake_vgw" {
  vpc_id = aws_vpc.cloudlake_core.id
  tags = var.tags
}

# VPC Endpoint (Interface Type for MSK)
resource "aws_vpc_endpoint" "cloudlake_msk_interface" {
  vpc_id            = aws_vpc.cloudlake_core.id
  service_name      = "com.amazonaws.${var.aws_region}.kafka"
  vpc_endpoint_type = "Interface"
  subnet_ids        = [aws_subnet.private_az1.id, aws_subnet.private_az2.id]
  security_group_ids = [aws_security_group.msk_sg.id]

  private_dns_enabled = true

  tags = var.tags
}
