module "label_vpc" {
  source     = "cloudposse/label/null"
  version    = "0.25.0"
  context    = module.base_label.context
  name       = "vpc"
  attributes = ["main"]
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = module.label_vpc.tags
}

# =========================
# Create your subnets here
# =========================


locals {
  subnet_cidr_public= cidrsubnet(var.vpc_cidr, 4, 0)
}

locals {
  subnet_cidr_private = cidrsubnet(var.vpc_cidr, 4, 1)
}



#Internet gateway for public subnet
resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.main.id
  tags = {      
    Name        = "module.label_vpc.tags"
  }
}

# Elastic IP for NAT 
resource "aws_eip" "nat_eip" {
  vpc        = true
  depends_on = [aws_internet_gateway.ig]
  tags       = module.label_vpc.tags
}

#NAT
resource "aws_nat_gateway" "nat" {
  allocation_id = "${aws_eip.nat_eip.id}"
  subnet_id     = "${aws_subnet.public_subnet.id}"  
  depends_on    = [aws_internet_gateway.ig]
  tags = {
    Name        = "module.label_vpc.tags"
  }
}

# Public subnet 
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "${local.subnet_cidr_public}"
  availability_zone       = "${var.aws_availability_zones}"
  map_public_ip_on_launch = true
  tags = {
    Name        = "module.label_vpc.tags"
  }
}

# Private subnet 
resource "aws_subnet" "private_subnet" {
  vpc_id                  = "${aws_vpc.main.id}"
  cidr_block              = "${local.subnet_cidr_private}"
  availability_zone       = "${var.aws_availability_zones}"
  map_public_ip_on_launch = false
  tags = {
    Name        = "module.label_vpc.tags"
  }
}

# Routing table for private subnet 
resource "aws_route_table" "private" {
  vpc_id = "${aws_vpc.main.id}"
  tags = {
    Name        = "module.label_vpc.tags"
  }
}

# Routing table for public subnet 
resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.main.id}"
  tags = {
    Name        =  "module.label_vpc.tags"
  }
}

resource "aws_route" "public_internet_gateway" {
  route_table_id         = "${aws_route_table.public.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.ig.id}"
}

resource "aws_route" "private_nat_gateway" {
  route_table_id         = "${aws_route_table.private.id}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = "${aws_nat_gateway.nat.id}"
}

# Route table associations 
resource "aws_route_table_association" "public" {
  subnet_id      = "${aws_subnet.public_subnet.id}"
  route_table_id = "${aws_route_table.public.id}"
}

resource "aws_route_table_association" "private" {
  subnet_id      = "${aws_subnet.private_subnet.id}"
  route_table_id = "${aws_route_table.private.id}"
}

# VPC's Default Security Group 
resource "aws_security_group" "default" {
  name        = "default-sg"
  description = "Default security group to allow inbound/outbound from the VPC"
  vpc_id      = "${aws_vpc.main.id}"
  depends_on  = [aws_vpc.main]
  ingress {
    from_port = "0"
    to_port   = "0"
    protocol  = "-1"
    self      = true
  }
  
  egress {
    from_port = "0"
    to_port   = "0"
    protocol  = "-1"
    self      = "true"
  }
}
