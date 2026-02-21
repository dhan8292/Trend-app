variable "region" {
  default = "us-west-2"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "azs" {
  default = ["us-west-2a", "us-west-2b"]
}

variable "ami" {
  default = "ami-075b5421f670d735c"
}

variable "instance_type" {
  default = "t3.small"
}

variable "public_key_path" {
  default = "~/.ssh/id_rsa.pub"
}
