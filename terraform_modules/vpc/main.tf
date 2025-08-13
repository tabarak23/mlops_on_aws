provider "aws" {
  region = "us-west-1"
}


locals {
  name= "${var.project_name}-${var.stage}"
 common_tags={
    Project= var.project_name
    Environment= var.stage
    ManagedBy= "Terraform"
 } 
}

#now creating vpc for the mlops rag project

resource "aws_vpc" "rag_vpc" {
  
  cidr_block= var.vpc_cidr
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
#fetching the names of availaialbe azs
data "aws_availability_zones" "available"{
    state= "available"
}

#now subnets 

#first public subnets
resource "aws_subnet" "public_subnet" {
  count= var.az_count
  vpc_id= aws_vpc.rag_vpc.id
  cidr_block= cidrsubnet(var.vpc_cidr,8,count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  map_public_ip_on_launch = true

  tags = {
    Name= "${local.name}-public-subnet-${count.index + 1}"
  }
}


#private  subnetss
resource "aws_subnet" "private" {
  count= var.az_count
  vpc_id= aws_vpc.main.id
  cidr_block= cidrsubnet(var.vpc_cidr, 8, count.index + var.az_count)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${local.name}-private-subnet-${count.index + 1}"
  }
}

#database subnets

resource "aws_subnet" "database" {
  count= var.az_count
  vpc_id= aws_vpc.main.id
  cidr_block= cidrsubnet(var.vpc_cidr, 8, count.index + 2 * var.az_count)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${local.name}-db-subnet-${count.index + 1}"
  }
}

