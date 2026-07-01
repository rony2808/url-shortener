terraform {
	required_providers {
		aws = {
			source = "hashicorp/aws"
			version = "~> 5.0"
		}
	}
}

provider "aws" {
	region = var.aws_region
}

data "aws_ami" "ubuntu" {
	most_recent = true
	owners      = ["099720109477"]

	filter {
		name   = "name"
		values = ["ubuntu/images/hvm-ssd*/ubuntu-noble-24.04-arm64-server-*"]
	}
	
	filter {
    		name   = "virtualization-type"
    		values = ["hvm"]
  	}
}

resource "aws_key_pair" "main" {
	key_name = "${var.project_name}-key"
	public_key = file(var.ssh_public_key_path)
}

resource "aws_vpc" "main" {
	cidr_block           = var.vpc_cidr
	enable_dns_support   = true
	enable_dns_hostnames = true

	tags = {
		Name = "${var.project_name}-vpc"
	}
}

resource "aws_subnet" "public" {
	vpc_id			= aws_vpc.main.id
	cidr_block		= var.public_subnet_cidr
	map_public_ip_on_launch = true

	tags = {
		Name = "${var.project_name}-public-subnet"
	}
}

resource "aws_internet_gateway" "main" {
	vpc_id = aws_vpc.main.id

	tags = {
		Name = "${var.project_name}-igw"
	}
}

resource "aws_route_table" "public" {
	vpc_id = aws_vpc.main.id
	
	route {
		cidr_block = "0.0.0.0/0"
		gateway_id = aws_internet_gateway.main.id
	}
	
	tags = {
		Name = "${var.project_name}-public-rt"
	}
}

resource "aws_route_table_association" "public" {
	subnet_id = aws_subnet.public.id
	route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "web" {
	name	    = "${var.project_name}-sg"
	description = "SSH from my IP, HTTP/HTTPS for all"
	vpc_id      = aws_vpc.main.id

	#SSH : only from my IP
	ingress {
		description = "SSH"
		from_port   = 22
		to_port     = 22
		protocol    = "tcp"
		cidr_blocks = [var.my_ip]
	}
	
	# HTTP: open for all
	ingress {
		description = "HTTP"
		from_port   = 80
		to_port     = 80
		protocol    = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}
	
	# HTTPS: open for all
	ingress {
		description = "HTTPS"
		from_port   = 443
		to_port     = 443
		protocol    = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}

	egress {
		from_port   = 0
		to_port     = 0
		protocol    = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}
	
	tags = {
		Name = "${var.project_name}-sg"
	}
}


resource "aws_instance" "app" {
	ami                    = data.aws_ami.ubuntu.id
	instance_type          = var.instance_type
	subnet_id              = aws_subnet.public.id
	vpc_security_group_ids = [aws_security_group.web.id]
	key_name               = aws_key_pair.main.key_name
		
	user_data = templatefile("${path.module}/user-data.sh", {
    		repo_url = var.repo_url
  	})
	user_data_replace_on_change = true
	root_block_device {
		volume_type = "gp3"
    		volume_size = 30
  	}

	tags = {
    		Name = "${var.project_name}-app"
  	}
}

resource "aws_eip" "app" {
  instance = aws_instance.app.id
  domain   = "vpc"

  tags = {
	Name = "${var.project_name}-eip"
  }
}
