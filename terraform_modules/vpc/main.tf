provider "aws" {
  region = "us-west-1"
}


locals {
  name= "${var.project_name}-${var.stage}"
 common_tags={
    Project= var.project_name
    environment= var.stage
    ManagedBy= "Terraform"
 } 
}

#now creating vpc for the mlops rag project

resource "aws_vpc" "rag_vpc" {
  
  cidr_block= var.cidr_block
  enable_dns_support= true
  enable_dns_hostnames = true
 

 tags = merge(
   {Name = "${local.name}-vpc"},
   local.common_tags
 )

 lifecycle {
   prevent_destroy = true
 }
}

resource "aws_internet_gateway" "rag_igw" {
  vpc_id= aws_vpc.rag_vpc.id


  tags = {
    Name = "${local.name}-igw"
  }
}
