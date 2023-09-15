#Define the variables
variable "azs" {
  type        = list(string)
  description = "list ofavailability zone"
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "region" {
  type        = string
  description = "Specify the region where the resources need to be dployed"
  default     = "us-east-1"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "vpc_cidr" {
  type        = string
  description = "provide a ip cidr valut to create vpc"
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  type        = list(string)
  description = "provide a list of ip cidr's to public subnets"
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnets" {
  type        = list(string)
  description = "provide a list of ip cidr's to private subnets"
  default     = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
}

variable "eip_count" {
  type        = string
  description = "specify a number to create Elastic IP's"
  default     = "3"
}

variable "domain_name" {
  type        = string
  description = "domain name to be hosted in route 53"
  default     = "test.com"
}

variable "custom_dns_name" {
  type        = string
  description = "domain name to be hosted in route 53"
  default     = "test-api"
}

variable "bastion_instance_count" {
  type        = string
  description = "specify the instance count for the bastion host"
  default     = "3"
}

variable "bastion_cidr" {
  type        = string
  description = "Allows users to access bastion hosts"
  default     = "192.168.0.0/16"
}

variable "bastion_server_instance_type" {
  type        = string
  description = "specify the instance type for the bastion host"
  default     = "t2.micro"
}

variable "backend_server_instance_type" {
  type        = string
  description = "specify the instance type for the asg instances"
  default     = "t2.micro"
}

variable "desired_capacity" {
  type        = string
  description = "specify a value to create the desired capacity of ec2 instances"
  default     = "3"
}

variable "min_size" {
  type        = string
  description = "specify a value to create the minimum capacity of ec2 instances"
  default     = "3"
}

variable "max_size" {
  type        = string
  description = "specify a value to create the maximum capacity of ec2 instances"
  default     = "6"
}
