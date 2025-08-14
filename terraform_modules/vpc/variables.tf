variable "project_name" {
  description= "name of the mlops project"
  type= string
}

variable "stage" {
  description= "where to deploy (dev,stag,prod)"
  type= string  
}

variable "aws_region" {
  description = "aws region"
  type= string
}

variable "vpc_cidr" {
  description = "cidr block for the vpc"
  type= string
  default = "10.0.0.0/16"  
}

variable "az_count" {
  description = "how many azs"
  type = number
  default = 2
}

variable "single_nat_gateway" {
  description = "we can use a single nat gateway instead of one per az if the env is dev"
  type= bool
  default = false
}

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs for network monitoring"
  type        = bool
  default     = false
}


variable "create_bastion_sg" {
  description = "Create a security group for bastion hosts"
  type        = bool
  default     = false
}




variable "bastion_allowed_cidr" {
  description = "CIDR blocks allowed to connect to bastion hosts"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}