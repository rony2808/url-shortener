variable "my_ip" {
	description = "My public IP on CIDR (x.x.x.x/32) that SSH allow"
	type        = string
}

variable "aws_region" {
	description = "AWS region of deployment"
	type        = string
	default     = "eu-central-1"
}

variable "project_name" {
	description = "Prefix used to name and tag resources"
	type        = string
	default     = "url-shortener"
}

variable "vpc_cidr" {
	description = "CIDR bloc of VPC"
	type        = string
	default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
	description = "CIDR bloc of public subnet"
	type        = string
	default	    = "10.0.1.0/24"
}

variable "ssh_public_key_path" {
	description = "Path to my local public SSH key"
	type        = string
	default     = "~/.ssh/id_ed25519.pub"
}

variable "repo_url" {
  	description = "HTTPS URL of the git clone repository at instance boot"
  	type        = string
  	default     = "https://github.com/rony2808/url-shortener.git"
}

variable "instance_type" {
  description = "Type d'instance EC2 (t4g.* = ARM, t3.* = x86)"
  type        = string
  default     = "t4g.small"
}



