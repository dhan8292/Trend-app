########################################
# Provider
########################################
provider "aws" {
  region = var.region
}

########################################
# Variables
########################################
variable "region" {
  default = "ap-south-1"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "azs" {
  default = ["ap-south-1a", "ap-south-1b"]
}

variable "ami" {
  default = "ami-06c643a49c853da56" # Jenkins EC2 AMI
}

variable "instance_type" {
  default = "t3.small"
}

variable "public_key_path" {
  default = "~/.ssh/id_rsa.pub"
}

########################################
# VPC
########################################
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "P2AD-vpc" }
}

########################################
# Internet Gateway
########################################
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "P2AD-igw" }
}

########################################
# Public Subnets
########################################
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = element(var.azs, count.index)
  map_public_ip_on_launch = true

  tags = { Name = "public-subnet-${count.index + 1}" }
}

########################################
# Private Subnets
########################################
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = element(var.azs, count.index)

  tags = { Name = "private-subnet-${count.index + 1}" }
}

########################################
# NAT Gateway
########################################
resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  depends_on    = [aws_internet_gateway.igw]
}

########################################
# Route Tables
########################################
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_assoc" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}

resource "aws_route_table_association" "private_assoc" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

########################################
# Key Pair
########################################
resource "aws_key_pair" "key" {
  key_name   = "terraform-key"
  public_key = file(var.public_key_path)
}

########################################
# Jenkins Security Group
########################################
resource "aws_security_group" "jenkins_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

########################################
# IAM Roles
########################################
# Jenkins EC2 Role
resource "aws_iam_role" "jenkins_ec2_role" {
  name = "jenkins-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "jenkins_policies" {
  for_each   = {
    "eks_cluster" = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
    "eks_worker"  = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    "ecr_read"    = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    "cni"         = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  }
  role       = aws_iam_role.jenkins_ec2_role.name
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "jenkins_profile" {
  name = "jenkins-instance-profile"
  role = aws_iam_role.jenkins_ec2_role.name
}
###################
# EKS Cluster Role
###################
resource "aws_iam_role" "eks_role" {
  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

################
# EKS Node Role
################
resource "aws_iam_role" "node_role" {
  name = "eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "node_policies" {
  for_each = {
    "worker" = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    "ecr"    = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    "cni"    = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  }
  role       = aws_iam_role.node_role.name
  policy_arn = each.value
}

########################################
# Jenkins EC2 Instance
########################################
resource "aws_instance" "jenkins" {
  ami           = var.ami
  instance_type = var.instance_type
  subnet_id     = aws_subnet.public[0].id
  key_name      = aws_key_pair.key.key_name

  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]

  iam_instance_profile = aws_iam_instance_profile.jenkins_profile.name

  user_data = file("jenkins.sh")

  tags = { Name = "jenkins-server" }
}

########################################
# EKS Cluster
########################################
resource "aws_eks_cluster" "eks" {
  name     = "P2AD-eks"
  role_arn = aws_iam_role.eks_role.arn

  vpc_config {
    subnet_ids = aws_subnet.private[*].id
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}

########################################
# EKS Node Group
########################################
resource "aws_eks_node_group" "nodes" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "P2AD-nodes"
  node_role_arn   = aws_iam_role.node_role.arn
  subnet_ids      = aws_subnet.private[*].id

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  instance_types = ["t3.small"]

  depends_on = [
    aws_eks_cluster.eks,
    aws_iam_role_policy_attachment.node_policies
  ]
}

########################################
# Outputs
########################################
output "jenkins_url" {
  value = "http://${aws_instance.jenkins.public_ip}:8080"
}

output "eks_cluster_name" {
  value = aws_eks_cluster.eks.name
}
