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

