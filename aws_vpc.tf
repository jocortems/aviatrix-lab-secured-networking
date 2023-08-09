resource "aws_vpc" "aws_vpc" {
  for_each              = { for each in local.aws_spoke : each.cidr => each }
  cidr_block            = each.value.cidr
  enable_dns_hostnames  = true
  enable_dns_support    = true
  tags = {
    Name = replace(each.value.vnet_name, "/", "-")
  }
}

resource "aws_subnet" "aviatrix_primary_gw" {
  for_each      = { for each in local.aws_spoke : each.cidr => each }
  vpc_id        = aws_vpc.aws_vpc[each.value.cidr].id
  cidr_block    = cidrsubnet(each.value.cidr, 8, 255)
  availability_zone = format("%sa", each.value.region)
  tags = {
    Name = format("avx-primarygw-%s", replace(each.value.vnet_name, "/", "-"))
  }
}

resource "aws_subnet" "aviatrix_ha_gw" {
  for_each      = { for each in local.aws_spoke : each.cidr => each }
  vpc_id        = aws_vpc.aws_vpc[each.value.cidr].id
  cidr_block    = cidrsubnet(each.value.cidr, 8, 254)
  availability_zone = format("%sb", each.value.region)
  tags = {
    Name = format("avx-hagw-%s", replace(each.value.vnet_name, "/", "-"))
  }
}

resource "aws_subnet" "aws_private_subnet_1" {
  for_each      = { for each in local.aws_spoke : each.cidr => each }
  vpc_id        = aws_vpc.aws_vpc[each.value.cidr].id
  cidr_block    = cidrsubnet(each.value.cidr, 8, 10)
  availability_zone = format("%sa", each.value.region)
  tags = {
    Name = format("private1-%s", replace(each.value.vnet_name, "/", "-"))
  }
}

resource "aws_subnet" "aws_private_subnet_2" {
  for_each      = { for each in local.aws_spoke : each.cidr => each }
  vpc_id        = aws_vpc.aws_vpc[each.value.cidr].id
  cidr_block    = cidrsubnet(each.value.cidr, 8, 15)
  availability_zone = format("%sb", each.value.region)
  tags = {
    Name = format("private2-%s", replace(each.value.vnet_name, "/", "-"))
  }
}

resource "aws_subnet" "eks_node_subnet_1" {
  for_each      = { for each in local.aws_spoke : each.cidr => each }
  vpc_id        = aws_vpc.aws_vpc[each.value.cidr].id
  cidr_block    = cidrsubnet(each.value.cidr, 8, 20)
  availability_zone = format("%sa", each.value.region)
  tags = {
    Name = format("eks-node1-%s", replace(each.value.vnet_name, "/", "-"))
    "kubernetes.io/cluster/eks-${var.k8s_cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb" = 1
  }
}

resource "aws_subnet" "eks_node_subnet_2" {
  for_each      = { for each in local.aws_spoke : each.cidr => each }
  vpc_id        = aws_vpc.aws_vpc[each.value.cidr].id
  cidr_block    = cidrsubnet(each.value.cidr, 8, 21)
  availability_zone = format("%sb", each.value.region)
  tags = {
    Name = format("eks-node2-%s", replace(each.value.vnet_name, "/", "-"))
    "kubernetes.io/cluster/eks-${var.k8s_cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb" = 1
  }
}

resource "aws_subnet" "eks_master_subnet_1" {
  for_each      = { for each in local.aws_spoke : each.cidr => each }
  vpc_id        = aws_vpc.aws_vpc[each.value.cidr].id
  cidr_block    = cidrsubnet(each.value.cidr, 8, 30)
  availability_zone = format("%sa", each.value.region)
  tags = {
    Name = format("eks-master1-%s", replace(each.value.vnet_name, "/", "-"))
  }
}

resource "aws_subnet" "eks_master_subnet_2" {
  for_each      = { for each in local.aws_spoke : each.cidr => each }
  vpc_id        = aws_vpc.aws_vpc[each.value.cidr].id
  cidr_block    = cidrsubnet(each.value.cidr, 8, 31)
  availability_zone = format("%sb", each.value.region)
  tags = {
    Name = format("eks-master2-%s", replace(each.value.vnet_name, "/", "-"))
  }
}

resource "aws_security_group" "private_subnet_sg" {
  for_each      = { for each in local.aws_spoke : each.cidr => each }
  name          = format("private-sg-%s", replace(each.value.vnet_name, "/", "-"))
  vpc_id        = aws_vpc.aws_vpc[each.value.cidr].id
  description   = "Allow all private traffic"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "rfc1918_a" {
    for_each      = { for each in local.aws_spoke : each.cidr => each }
    description   = "Allow all private traffic"
    ip_protocol      = "-1"
    security_group_id = aws_security_group.private_subnet_sg[each.value.cidr].id
    cidr_ipv4     = "10.0.0.0/8"
}

resource "aws_vpc_security_group_ingress_rule" "rfc1918_b" {
    for_each      = { for each in local.aws_spoke : each.cidr => each }
    description   = "Allow all private traffic"
    ip_protocol      = "-1"
    security_group_id = aws_security_group.private_subnet_sg[each.value.cidr].id
    cidr_ipv4     = "172.16.0.0/12"
}

resource "aws_vpc_security_group_ingress_rule" "rfc1918_c" {
    for_each      = { for each in local.aws_spoke : each.cidr => each }
    description   = "Allow all private traffic"
    ip_protocol      = "-1"
    security_group_id = aws_security_group.private_subnet_sg[each.value.cidr].id
    cidr_ipv4     = "192.168.0.0/16"
}

resource "aws_vpc_security_group_ingress_rule" "cgnat" {
    for_each      = { for each in local.aws_spoke : each.cidr => each }
    description   = "Allow all private traffic"
    ip_protocol      = "-1"
    security_group_id = aws_security_group.private_subnet_sg[each.value.cidr].id
    cidr_ipv4     = "100.64.0.0/10"
}

resource "aws_vpc_security_group_egress_rule" "all" {
    for_each      = { for each in local.aws_spoke : each.cidr => each }
    description   = "Allow all outbound traffic"
    ip_protocol      = "-1"
    security_group_id = aws_security_group.private_subnet_sg[each.value.cidr].id
    cidr_ipv4    = "0.0.0.0/0"
}

resource "aws_internet_gateway" "aws_igw" {
  for_each      = { for each in local.aws_spoke : each.cidr => each }
  vpc_id        = aws_vpc.aws_vpc[each.value.cidr].id
  tags = {
    Name = format("avx-igw-%s", replace(each.value.vnet_name, "/", "-"))
  }
}

resource "aws_route_table" "aws_public_route_table" {
  for_each      = { for each in local.aws_spoke : each.cidr => each }
  vpc_id        = aws_vpc.aws_vpc[each.value.cidr].id
}

resource "aws_route" "default_route" {
  for_each      = { for each in local.aws_spoke : each.cidr => each }
  route_table_id = aws_route_table.aws_public_route_table[each.value.cidr].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.aws_igw[each.value.cidr].id
}

resource "aws_route_table_association" "avx_primary_gw_rt_association" {
  for_each      = { for each in local.aws_spoke : each.cidr => each }
  subnet_id     = aws_subnet.aviatrix_primary_gw[each.value.cidr].id
  route_table_id = aws_route_table.aws_public_route_table[each.value.cidr].id
}

resource "aws_route_table_association" "avx_ha_gw_rt_association" {
  for_each      = { for each in local.aws_spoke : each.cidr => each }
  subnet_id     = aws_subnet.aviatrix_ha_gw[each.value.cidr].id
  route_table_id = aws_route_table.aws_public_route_table[each.value.cidr].id
}

resource "aws_route_table" "aws_private_route_table_1" {
  for_each      = { for each in local.aws_spoke : each.cidr => each }
  vpc_id        = aws_vpc.aws_vpc[each.value.cidr].id
}

resource "aws_route_table" "aws_private_route_table_2" {
  for_each      = { for each in local.aws_spoke : each.cidr => each }
  vpc_id        = aws_vpc.aws_vpc[each.value.cidr].id
}

resource "aws_route_table_association" "private_subnet_1_rt_association" {
  for_each      = { for each in local.aws_spoke : each.cidr => each }
  subnet_id     = aws_subnet.aws_private_subnet_1[each.value.cidr].id
  route_table_id = aws_route_table.aws_private_route_table_1[each.value.cidr].id
}

resource "aws_route_table_association" "private_subnet_2_rt_association" {
  for_each      = { for each in local.aws_spoke : each.cidr => each }
  subnet_id     = aws_subnet.aws_private_subnet_2[each.value.cidr].id
  route_table_id = aws_route_table.aws_private_route_table_2[each.value.cidr].id
}

resource "aws_route_table_association" "eks_node1_rt_association" {
  for_each      = { for each in local.aws_spoke : each.cidr => each }
  subnet_id     = aws_subnet.eks_node_subnet_1[each.value.cidr].id
  route_table_id = aws_route_table.aws_private_route_table_1[each.value.cidr].id
}

resource "aws_route_table_association" "eks_node2_rt_association" {
  for_each      = { for each in local.aws_spoke : each.cidr => each }
  subnet_id     = aws_subnet.eks_node_subnet_2[each.value.cidr].id
  route_table_id = aws_route_table.aws_private_route_table_1[each.value.cidr].id
}

resource "aws_route_table_association" "eks_master1_rt_association" {
  for_each      = { for each in local.aws_spoke : each.cidr => each }
  subnet_id     = aws_subnet.eks_master_subnet_1[each.value.cidr].id
  route_table_id = aws_route_table.aws_public_route_table[each.value.cidr].id
}

resource "aws_route_table_association" "eks_master2_rt_association" {
  for_each      = { for each in local.aws_spoke : each.cidr => each }
  subnet_id     = aws_subnet.eks_master_subnet_2[each.value.cidr].id
  route_table_id = aws_route_table.aws_public_route_table[each.value.cidr].id
}


resource "aws_key_pair" "aws_key_pair" {
  for_each = var.aws_spoke_vnets
  public_key = file(var.ssh_public_key_file)
}


resource "aws_instance" "ec2_1" {
  for_each      = { for each in local.aws_spoke : each.cidr => each }
  ami           = data.aws_ami.ubuntu20_04.id
  instance_type = var.aws_vmSKU
  key_name      = aws_key_pair.aws_key_pair[each.value.region].key_name
  subnet_id     = aws_subnet.aws_private_subnet_1[each.value.cidr].id
  vpc_security_group_ids = [aws_security_group.private_subnet_sg[each.value.cidr].id]
  associate_public_ip_address = false
  tags = {
    Name = format("aws-prod1-%s", replace(each.value.vnet_name, "/", "-"))
    environment = "prod"
    avx_spoke = aviatrix_spoke_transit_attachment.aws_uswest2[each.value.cidr].spoke_gw_name
  }
  disable_api_termination = false
  private_ip = cidrhost(aws_subnet.aws_private_subnet_1[each.value.cidr].cidr_block, 11)
  user_data = "${file("cloud-init.sh")}"
}

resource "aws_instance" "ec2_12" {
  for_each      = { for each in local.aws_spoke : each.cidr => each }
  ami           = data.aws_ami.ubuntu20_04.id
  instance_type = var.aws_vmSKU
  key_name      = aws_key_pair.aws_key_pair[each.value.region].key_name
  subnet_id     = aws_subnet.aws_private_subnet_1[each.value.cidr].id
  vpc_security_group_ids = [aws_security_group.private_subnet_sg[each.value.cidr].id]
  associate_public_ip_address = false
  tags = {
    Name = format("aws-dev1-%s", replace(each.value.vnet_name, "/", "-"))
    environment = "dev"
    avx_spoke = aviatrix_spoke_transit_attachment.aws_uswest2[each.value.cidr].spoke_gw_name
  }
  disable_api_termination = false
  private_ip = cidrhost(aws_subnet.aws_private_subnet_1[each.value.cidr].cidr_block, 21)
  user_data = "${file("cloud-init.sh")}"
}

resource "aws_instance" "ec2_2" {
  for_each      = { for each in local.aws_spoke : each.cidr => each }
  ami           = data.aws_ami.ubuntu20_04.id
  instance_type = var.aws_vmSKU
  key_name      = aws_key_pair.aws_key_pair[each.value.region].key_name
  subnet_id     = aws_subnet.aws_private_subnet_2[each.value.cidr].id
  vpc_security_group_ids = [aws_security_group.private_subnet_sg[each.value.cidr].id]
  associate_public_ip_address = false
  tags = {
    Name = format("aws-prod2-%s", replace(each.value.vnet_name, "/", "-"))
    environment = "prod"
    avx_spoke = aviatrix_spoke_transit_attachment.aws_uswest2[each.value.cidr].spoke_gw_name
  }
  disable_api_termination = false
  private_ip = cidrhost(aws_subnet.aws_private_subnet_2[each.value.cidr].cidr_block, 11)
  user_data = "${file("cloud-init.sh")}"
}

resource "aws_instance" "ec2_21" {
  for_each      = { for each in local.aws_spoke : each.cidr => each }
  ami           = data.aws_ami.ubuntu20_04.id
  instance_type = var.aws_vmSKU
  key_name      = aws_key_pair.aws_key_pair[each.value.region].key_name
  subnet_id     = aws_subnet.aws_private_subnet_2[each.value.cidr].id
  vpc_security_group_ids = [aws_security_group.private_subnet_sg[each.value.cidr].id]
  associate_public_ip_address = false
  tags = {
    Name = format("aws-dev2-%s", replace(each.value.vnet_name, "/", "-"))
    environment = "dev"
    avx_spoke = aviatrix_spoke_transit_attachment.aws_uswest2[each.value.cidr].spoke_gw_name
  }
  disable_api_termination = false
  private_ip = cidrhost(aws_subnet.aws_private_subnet_2[each.value.cidr].cidr_block, 21)
  user_data = "${file("cloud-init.sh")}"
}
