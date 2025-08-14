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
  vpc_id= aws_vpc.rag_vpc.id
  cidr_block= cidrsubnet(var.vpc_cidr, 8, count.index + var.az_count)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${local.name}-private-subnet-${count.index + 1}"
  }
}

#database subnets

resource "aws_subnet" "database" {
  count= var.az_count
  vpc_id= aws_vpc.rag_vpc.id
  cidr_block= cidrsubnet(var.vpc_cidr, 8, count.index + 2 * var.az_count)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${local.name}-db-subnet-${count.index + 1}"
  }
}

#now creating 2 elasticas ips for natgateway

resource "aws_eip" "rag_eip" {
  count= var.az_count
  domain = "vpc"
  
  tags = {
    Name= "${local.name}-eip-${count.index + 1}"
  }

depends_on = [ aws_internet_gateway.rag_igw ]

}

#now creating the nat gateways
          
resource "aws_nat_gateway" "rag_nat" {
  count         = var.single_nat_gateway ? 1 : var.az_count
  allocation_id = aws_eip.rag_eip[count.index].id 
  subnet_id = aws_subnet.public_subnet[count.index].id

  tags = merge(
    { Name= "${local.name}-nat-rag${count.index + 1}" },
    local.common_tags
  )
}

#nroutes tables 

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.rag_vpc.id
  tags={
    Name = "${local.name}-public-route-table"
  }
}

  resource "aws_route" "public_igw" {
    route_table_id = aws_route_table.public.id
    destination_cidr_block = "0.0.0.0/0" #source 
    gateway_id= aws_internet_gateway.rag_igw.id #destination
  }

# note : here i separeted the routes from the route table section to have separate creation and if there's any change in future 
#in the destination then there will be less downtime coz the aws will just change the route instead of deleteing and creating the 
#complete route table(only if i placed the route in the route table seciton)
  

resource "aws_route_table" "private" {
 count  = var.az_count
 vpc_id = aws_vpc.rag_vpc.id
 
 tags = merge(
  { Name= "${local.name}-private-route_table-${count.index + 1}" },
  local.common_tags
)
}
 resource "aws_route" "private_nat" {
  count = var.single_nat_gateway ? 1 : var.az_count
  route_table_id = aws_route_table.private[count.index].id
  destination_cidr_block= "0.0.0.0/0" #source 
  nat_gateway_id= var.single_nat_gateway ? aws_nat_gateway.rag_nat[0].id : aws_nat_gateway.rag_nat[count.index].id #destination
 
}


# note : here i separeted the routes from the route table section to have separate creation and if there's any change in future 
#in the destination then there will be less downtime coz the aws will just change the route instead of deleteing and creating the 
#complete route table(only if i placed the route in the route table seciton)

#attaching route tables to subnets

resource "aws_route_table_association" "public" {
  count = var.az_count
  subnet_id = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public.id
  }
resource "aws_route_table_association" "private" {
  count = var.az_count
  subnet_id = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

#vpc flow

resource "aws_iam_role" "flow_logs" {
  name = "${var.project_name}-${var.stage}-flow-logs-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "flow_logs" {
  role       = aws_iam_role.flow_logs.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_cloudwatch_log_group" "flow_log" {
  count             = var.enable_flow_logs ? 1 : 0
  name              = "/aws/vpc/flowlogs/${local.name}"
  retention_in_days = 7

  tags = local.common_tags
}

resource "aws_flow_log" "main" {
  count                = var.enable_flow_logs ? 1 : 0
  log_destination      = aws_cloudwatch_log_group.flow_log[0].arn
  log_destination_type = "cloud-watch-logs"
  iam_role_arn         = aws_iam_role.flow_logs.arn
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.rag_vpc.id

  tags = merge(
    { Name = "${local.name}-vpc-flow-log" },
    local.common_tags
  )
}

#security groups



resource "aws_security_group" "bastion" {
  count       = var.create_bastion_sg ? 1 : 0
  name        = "${local.name}-bastion-sg"
  description = "Security group for bastion hosts"
  vpc_id      = aws_vpc.rag_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.bastion_allowed_cidr
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    { Name = "${local.name}-bastion-sg" },
    local.common_tags
  )
}

resource "aws_security_group" "lambda" {
  name        = "${local.name}-lambda-sg"
  description = "Security group for Lambda functions"
  vpc_id      = aws_vpc.rag_vpc.id

  # Allow all outbound traffic (including HTTP/HTTPS for MCP)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name}-lambda-sg"
  }
}

resource "aws_security_group" "database" {
  name        = "${local.name}-db-sg"
  description = "Security group for PostgreSQL RDS"
  vpc_id      = aws_vpc.rag_vpc.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name}-db-sg"
  }
}


#db sunet group 

resource "aws_db_subnet_group" "main" {
  name        = "${local.name}-db-subnet-group"
  description = "Database subnet group for ${local.name}"
  subnet_ids  = aws_subnet.database[*].id

  tags = {
    Name = "${local.name}-db-subnet-group"
  }
}

# vpc endpoints



resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.rag_vpc.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [for rt in aws_route_table.private : rt.id]

  tags = {
    Name = "${local.name}-s3-endpoint"
  }
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.rag_vpc.id
  service_name      = "com.amazonaws.${var.aws_region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [for rt in aws_route_table.private : rt.id]

  tags = {
    Name = "${local.name}-dynamodb-endpoint"
  }
}