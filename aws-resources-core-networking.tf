resource "aws_vpc" "cloudlake_core" {
  cidr_block = "10.0.0.0/16"
  tags = var.tags
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
