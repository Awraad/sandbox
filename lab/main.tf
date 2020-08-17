provider "random" {}

module "tags_network" {
  source      = "git::https://github.com/cloudposse/terraform-null-label.git"
  namespace   = var.name
  environment = "dev"
  name        = "devops-bootcamp"
  delimiter   = "_"

  tags = {
    owner = var.name
    type  = "network"
  }
}

module "tags_sandbox" {
  source      = "git::https://github.com/cloudposse/terraform-null-label.git"
  namespace   = var.name
  environment = "dev"
  name        = "sandbox-devops-bootcamp"
  delimiter   = "_"

  tags = {
    owner = var.name
    type  = "sandbox"
  }
}

resource "aws_vpc" "k8s_lab" {
  cidr_block           = "10.0.0.0/16"
  tags                 = module.tags_network.tags
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "lab_gateway" {
  vpc_id = aws_vpc.k8s_lab.id
  tags   = module.tags_network.tags
}

resource "aws_route" "lab_internet_access" {
  route_table_id         = aws_vpc.k8s_lab.main_route_table_id
  gateway_id             = aws_internet_gateway.lab_gateway.id
  destination_cidr_block = "0.0.0.0/0"
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "sandbox" {
  vpc_id                  = aws_vpc.k8s_lab.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]
  tags                    = module.tags_sandbox.tags
}

resource "aws_security_group" "sandbox" {
  vpc_id = aws_vpc.k8s_lab.id
  tags   = module.tags_sandbox.tags

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "random_id" "keypair" {
  keepers = {
    public_key = file(var.public_key_path)
  }

  byte_length = 8
}

resource "aws_key_pair" "lab_keypair" {
  key_name   = format("%s_keypair_%s", var.name, random_id.keypair.hex)
  public_key = random_id.keypair.keepers.public_key
}

resource "aws_instance" "sandbox" {
  ami                    = "ami-02c7c728a7874ae7a"
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.sandbox.id
  vpc_security_group_ids = [aws_security_group.sandbox.id]
  key_name               = aws_key_pair.lab_keypair.id
  tags                   = module.tags_sandbox.tags
}