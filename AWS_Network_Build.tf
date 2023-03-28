##########Default Terraform Information##########
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
  
  required_version = ">= 1.2.0"
}


##########Provider Information##########
provider "aws" {
	region  = "us-west-2"
}

##########Variable Information##########
variable "second_octet" {
	type = string
	default = "0"
}

variable "department" {
	type = string
	default = "Portal PC & Gaming"
}

variable "region" {
	type = string
	default = "us-west-2"
}


##########Creation of Resources##########
#####VPC#####
resource "aws_vpc" "main" {
	cidr_block = "10.${var.second_octet}.0.0/16"
	
	tags = {
		Name = "${var.department} Main VPC"
	}
}

#####Gateways#####
resource "aws_internet_gateway" "main" {
	vpc_id = aws_vpc.main.id
	
	tags = {
		Name = "${var.department} Internet Gateway"
	}
	
	depends_on = [aws_vpc.main]
}

resource "aws_nat_gateway" "main" {
	allocation_id = aws_eip.main.id
	subnet_id = aws_subnet.primary_public.id
	
	tags = {
		Name = "${var.department} NAT Gateway"
	}
	
	depends_on = [aws_subnet.primary_public, aws_eip.main]
}

resource "aws_ec2_transit_gateway_vpc_attachment" "main" {
	subnet_ids = [aws_subnet.primary_production.id, aws_subnet.secondary_production.id, aws_subnet.primary_test.id, aws_subnet.primary_workspace.id]
	transit_gateway_id = "tgw-01dde3b1b5bde0b36"
	vpc_id = aws_vpc.main.id
	
	tags = {
		Name = "Inbound VPN Transit Gateway Attachment"
	}
	
	depends_on = [aws_vpc.main, aws_subnet.primary_production, aws_subnet.secondary_production, aws_subnet.primary_test, aws_subnet.primary_workspace]
}

#####Subnets#####
resource "aws_subnet" "primary_production" {
	vpc_id = aws_vpc.main.id
	cidr_block = "10.${var.second_octet}.1.0/24"
	availability_zone = "${var.region}a"
	
	tags = {
		Name = "${var.department} Primary Production Subnet"
	}
	
	depends_on = [aws_vpc.main]
}

resource "aws_subnet" "secondary_production" {
	vpc_id = aws_vpc.main.id
	cidr_block = "10.${var.second_octet}.2.0/24"
	availability_zone = "${var.region}b"
	
	tags = {
		Name = "${var.department} Secondary Production Subnet"
	}
	
	depends_on = [aws_vpc.main]
}

resource "aws_subnet" "primary_test" {
	vpc_id = aws_vpc.main.id
	cidr_block = "10.${var.second_octet}.20.0/24"
	availability_zone = "${var.region}c"
	
	tags = {
		Name = "${var.department} Primary Testing Subnet"
	}
	
	depends_on = [aws_vpc.main]
}

resource "aws_subnet" "secondary_test" {
	vpc_id = aws_vpc.main.id
	cidr_block = "10.${var.second_octet}.21.0/24"
	availability_zone = "${var.region}a"
	
	tags = {
		Name = "${var.department} Secondary Testing Subnet"
	}
	
	depends_on = [aws_vpc.main]
}

resource "aws_subnet" "primary_workspace" {
	vpc_id = aws_vpc.main.id
	cidr_block = "10.${var.second_octet}.50.0/24"
	availability_zone = "${var.region}d"
	
	tags = {
		Name = "${var.department} Primary Workspaces Subnet"
	}
	
	depends_on = [aws_vpc.main]
}

resource "aws_subnet" "secondary_workspace" {
	vpc_id = aws_vpc.main.id
	cidr_block = "10.${var.second_octet}.51.0/24"
	availability_zone = "${var.region}b"
	
	tags = {
		Name = "${var.department} Secondary Workspaces Subnet"
	}
	
	depends_on = [aws_vpc.main]
}

resource "aws_subnet" "primary_public" {
	vpc_id = aws_vpc.main.id
	cidr_block = "10.${var.second_octet}.254.0/24"
	availability_zone = "${var.region}c"
	
	tags = {
		Name = "${var.department} Primary Public Subnet"
	}
	
	depends_on = [aws_vpc.main]
}

resource "aws_subnet" "secondary_public" {
	vpc_id = aws_vpc.main.id
	cidr_block = "10.${var.second_octet}.255.0/24"
	availability_zone = "${var.region}d"
	
	tags = {
		Name = "${var.department} Secondary Public Subnet"
	}
	
	depends_on = [aws_vpc.main]
}

####Route Tables & Associations#####
resource "aws_route_table" "public_route_table" {
	vpc_id = aws_vpc.main.id
	
	route {
		cidr_block = "0.0.0.0/0"
		gateway_id = aws_internet_gateway.main.id
	}
	
	route {
		cidr_block = "10.150.0.0/16"
		transit_gateway_id = "tgw-01dde3b1b5bde0b36"
	}
	
	route {
		cidr_block = "10.0.0.0/8"
		transit_gateway_id = "tgw-01dde3b1b5bde0b36"
	}
	
	tags = {
		Name = "${var.department} Public Route Table"
	}
	
	depends_on = [aws_ec2_transit_gateway_vpc_attachment.main, aws_internet_gateway.main]
}

resource "aws_route_table" "private_route_table" {
	vpc_id = aws_vpc.main.id
	
	route {
		cidr_block = "0.0.0.0/0"
		nat_gateway_id = aws_nat_gateway.main.id
	}
	
	route {
		cidr_block = "10.0.0.0/8"
		transit_gateway_id = "tgw-01dde3b1b5bde0b36"
	}
	
	route {
		cidr_block = "10.150.0.0/16"
		transit_gateway_id = "tgw-01dde3b1b5bde0b36"
	}

	tags = {
		Name = "${var.department} Private Route Table"
	}
	
	depends_on = [aws_ec2_transit_gateway_vpc_attachment.main, aws_nat_gateway.main]
}

resource "aws_route_table_association" "primary_production" {
	subnet_id = aws_subnet.primary_production.id
	route_table_id = aws_route_table.private_route_table.id
	
	depends_on = [aws_route_table.private_route_table]
}

resource "aws_route_table_association" "secondary_production" {
	subnet_id = aws_subnet.secondary_production.id
	route_table_id = aws_route_table.private_route_table.id
	
	depends_on = [aws_route_table.private_route_table]
}

resource "aws_route_table_association" "primary_test" {
	subnet_id = aws_subnet.primary_test.id
	route_table_id = aws_route_table.private_route_table.id
	
	depends_on = [aws_route_table.private_route_table]
}

resource "aws_route_table_association" "secondary_test" {
	subnet_id = aws_subnet.secondary_test.id
	route_table_id = aws_route_table.private_route_table.id
	
	depends_on = [aws_route_table.private_route_table]
}

resource "aws_route_table_association" "primary_workspace" {
	subnet_id = aws_subnet.primary_workspace.id
	route_table_id = aws_route_table.private_route_table.id
	
	depends_on = [aws_route_table.private_route_table]
}

resource "aws_route_table_association" "secondary_workspace" {
	subnet_id = aws_subnet.secondary_workspace.id
	route_table_id = aws_route_table.private_route_table.id
	
	depends_on = [aws_route_table.private_route_table]
}

resource "aws_route_table_association" "primary_public" {
	subnet_id = aws_subnet.primary_public.id
	route_table_id = aws_route_table.public_route_table.id
	
	depends_on = [aws_route_table.public_route_table]
}

resource "aws_route_table_association" "secondary_public" {
	subnet_id = aws_subnet.secondary_public.id
	route_table_id = aws_route_table.public_route_table.id
	
	depends_on = [aws_route_table.public_route_table]
}

#####Security Groups#####
resource "aws_security_group" "allow_all_internal" {
	name = "Allow-All-Internal"
	description = "Allows access to all ports/ICMP to all internal IP ranges"
	vpc_id = aws_vpc.main.id
	
	ingress {
		from_port       = 0
		to_port         = 0
		protocol        = "-1"
		prefix_list_ids = [aws_ec2_managed_prefix_list.main.id]
	}
	
	ingress {
		from_port       = -1
		to_port         = -1
		protocol        = "icmp"
		prefix_list_ids = [aws_ec2_managed_prefix_list.main.id]
	}
	
	egress {
		from_port        = 0
		to_port          = 0
		protocol         = "-1"
		cidr_blocks      = ["0.0.0.0/0"]
		ipv6_cidr_blocks = ["::/0"]
	}
	
	tags = {
		Name = "Allow-All-Internal"
	}
	
	depends_on = [aws_vpc.main, aws_ec2_managed_prefix_list.main]
	
}

resource "aws_security_group" "ssh_targeted" {
	name = "SSH-Targeted"
	description = "Allows access to port 22 to all internal IP ranges"
	vpc_id = aws_vpc.main.id
	
	ingress {
		from_port       = 22
		to_port         = 22
		protocol        = "tcp"
		prefix_list_ids = [aws_ec2_managed_prefix_list.main.id]
	}
	
	egress {
		from_port        = 0
		to_port          = 0
		protocol         = "-1"
		cidr_blocks      = ["0.0.0.0/0"]
		ipv6_cidr_blocks = ["::/0"]
	}
	
	tags = {
		Name = "SSH-Targeted"
	}
	
	depends_on = [aws_vpc.main, aws_ec2_managed_prefix_list.main]
}

resource "aws_security_group" "rdp_targeted" {
	name = "RDP-Targeted"
	description = "Allows access to port 3389 to all internal IP ranges"
	vpc_id = aws_vpc.main.id
	
	ingress {
		from_port       = 3389
		to_port         = 3389
		protocol        = "tcp"
		prefix_list_ids = [aws_ec2_managed_prefix_list.main.id]
	}
	
	egress {
		from_port        = 0
		to_port          = 0
		protocol         = "-1"
		cidr_blocks      = ["0.0.0.0/0"]
		ipv6_cidr_blocks = ["::/0"]
	}
	
	tags = {
		Name = "RDP-Targeted"
	}
	
	depends_on = [aws_vpc.main, aws_ec2_managed_prefix_list.main]
}

resource "aws_security_group" "dns_general" {
	name = "DNS-General"
	description = "Allows access to port 53 to all IP addresses"
	vpc_id = aws_vpc.main.id
	
	ingress {
		from_port       = 53
		to_port         = 53
		protocol        = "tcp"
		cidr_blocks      = ["0.0.0.0/0"]
		ipv6_cidr_blocks = ["::/0"]
	}
	
	ingress {
		from_port       = 53
		to_port         = 53
		protocol        = "udp"
		cidr_blocks      = ["0.0.0.0/0"]
		ipv6_cidr_blocks = ["::/0"]
	}
	
	egress {
		from_port        = 0
		to_port          = 0
		protocol         = "-1"
		cidr_blocks      = ["0.0.0.0/0"]
		ipv6_cidr_blocks = ["::/0"]
	}
	
	tags = {
		Name = "DNS-General"
	}
	
	depends_on = [aws_vpc.main]
}

#####SEANET Outbound DNS Resolver#####
resource "aws_route53_resolver_endpoint" "seanet" {
  name      = "SEANET-Outbound-Resolver-Endpoint"
  direction = "OUTBOUND"
  
  security_group_ids = [aws_security_group.dns_general.id]
  
  ip_address {
	subnet_id = aws_subnet.primary_production.id
  }
  
  ip_address {
	subnet_id = aws_subnet.secondary_production.id
  }
  
  ip_address {
	subnet_id = aws_subnet.primary_test.id
  }
  
  ip_address {
	subnet_id = aws_subnet.primary_workspace.id
  }
  
  tags = {
		Name = "SEANET Outbound Resolver Endpoint"
	}
	
	depends_on = [
		aws_security_group.dns_general, 
		aws_subnet.primary_production, 
		aws_subnet.secondary_production, 
		aws_subnet.primary_test,
		aws_subnet.primary_workspace
	]
}

resource "aws_route53_resolver_rule" "seanet" {
	domain_name = "corp.portalpcgaming.com"
	name = "SEANET-Outbound-Resolver"
	rule_type = "FORWARD"
	resolver_endpoint_id = aws_route53_resolver_endpoint.seanet.id
	
	target_ip {
		ip = "10.150.1.5"
	}
	
	target_ip {
		ip = "10.5.10.7"
	}
	
	tags = {
		Name = "SEANET Outbound Resolver"
	}
	
	depends_on = [aws_route53_resolver_endpoint.seanet]
}

resource "aws_route53_resolver_rule_association" "seanet" {
	resolver_rule_id = aws_route53_resolver_rule.seanet.id
	vpc_id = aws_vpc.main.id
	
	depends_on = [aws_route53_resolver_rule.seanet]
}

#####Misc Networking#####
resource "aws_eip" "main" {
	vpc = true
	
	tags = {
		Name = "${var.department} NAT Gateway EIP"
	}
}

resource "aws_ec2_managed_prefix_list" "main" {
	name = "Portal PC & Gaming IP Prefix List"
	address_family = "IPv4"
	max_entries = 20
	
	entry {
		cidr = "10.0.0.0/8"
		description = "Portal PC & Gaming Intranet"
	}
	
	entry {
		cidr = "65.153.190.148/32"
		description = "Bellevue Circuit"
	}
	
	entry {
		cidr = "59.124.102.130/32"
		description = "Taiwan Circuit"
	}
	
	entry {
		cidr = "213.27.238.154/32"
		description = "Madrid Colt Circuit"
	}
	
	entry {
		cidr = "50.228.204.218/32"
		description = "Bellevue Circuit"
	}
	
	entry {
		cidr = "154.62.65.98/32"
		description = "Madrid Lyntia Circuit"
	}
	
	entry {
		cidr = "122.146.9.98/32"
		description = "Taiwan Circuit"
	}
	
	tags = {
		Name = "Portal PC & Gaming IP Prefix List"
	}
	
}