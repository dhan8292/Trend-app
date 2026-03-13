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
  default = "ami-06c643a49c853da56"
}

variable "instance_type" {
  default = "t3.small"
}

variable "public_key_path" {
  default = "~/.ssh/id_rsa.pub"
}
