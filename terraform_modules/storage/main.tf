#here im creating the storage for the mlops rag project


#tags for the storages
locals {
  bucket_name= "${var.project_name}-${var.stage}-documents"
  logs_bucket= "${var.project_name}-${var.stage}-logs"
  table_name = "${var.project_name}-${var.stage}-metadata"
  common_tags ={
    Project= var.project_name
    Environment= var.stage
    ManagedBy= "Terraform"
  }
}

#storage for documents
resource "aws_s3_bucket" "rag_s3" {
  bucket=  local.bucket_name
  tags = {
    Name= local.bucket_name
    Environment= var.stage
  }

  lifecycle {
    prevent_destroy = true
  }
}

#versoios for s3

resource "aws_s3_bucket_versioning" "rag_versioning" {
  bucket= aws_s3_bucket.rag_s3.id
  versioning_configuration {
    status = "Enabled"
  }
}



#ENCRYPTING the documents in the bucket for security 
resource "aws_s3_bucket_server_side_encryption_configuration" "rag_s3_encypt" {
  bucket = aws_s3_bucket.rag_s3.id


  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}


# giving access to unknonw resources for using my s3 bucket 
resource "aws_s3_bucket_cors_configuration" "rag_documents" {
  bucket = aws_s3_bucket.rag_s3.id

  cors_rule {
    allowed_headers = ["Authorization", "Content-Type"]
    allowed_methods = ["GET", "POST", "PUT"]
    allowed_origins = ["*"]
    max_age_seconds = 3000
  }
}

#lifecycle iof the documents in the bucket 

resource "aws_s3_bucket_lifecycle_configuration" "rag_s3_lifecycle" {
  bucket = aws_s3_bucket.rag_s3.id

  rule{
    id ="archive_old_documnt"
    status = "Enabled"


    filter {
      prefix = ""
    }



    transition {
      days = 60
      storage_class = "STANDARD_IA"
    }

    transition {
      days=90
      storage_class = "GLACIER"

    }
  }


}

#blocking public access

resource "aws_s3_bucket_public_access_block" "rag_block_s3" {
  bucket                  = aws_s3_bucket.rag_s3.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


#creating the log bucket fro the production only 

resource "aws_s3_bucket" "logs" {
  count= var.stage == "prod" ? 1 : 0
  bucket =local.logs_bucket

  tags = merge(
    local.common_tags,
    {
      Name= local.logs_bucket
      Purpose= "S3 Access Logs Storage"
    }
  )

  lifecycle {
    prevent_destroy = true
  }
}

# Block public access for logs bucket
resource "aws_s3_bucket_public_access_block" "logs_block" {
  count= var.stage == "prod" ? 1 : 0
  bucket= aws_s3_bucket.logs[0].id
  block_public_acls= true
  block_public_policy= true
  ignore_public_acls= true
  restrict_public_buckets =true
}

resource "aws_s3_bucket_logging" "rag_s3_logging" {
  count= var.stage == "prod" ? 1 : 0
  bucket= aws_s3_bucket.rag_s3.id
  target_bucket= aws_s3_bucket.logs[0].id
  target_prefix = "s3-access-logs/"
}


#now creating dynamodb for metadara

resource "aws_dynamodb_table" "rag_dynamo" {
  name=local.table_name
  billing_mode = "PAY_PER_REQUEST"  
  hash_key= "id"
  

  attribute {
    name= "id"
    type= "S"
  }
  attribute {
    name ="user_id"
    type= "S"
  }
  attribute {
    name= "document_id"
    type= "S"
  }
  


  global_secondary_index {
    name= "UserIndex"
    hash_key= "user_id"
    projection_type= "ALL"
  }
  
  global_secondary_index {
    name= "DocumentIndex"
    hash_key= "document_id"
    projection_type= "ALL"
  }
  point_in_time_recovery {
    enabled= true
  }
  
  server_side_encryption {
    enabled= false
  }
  tags = {
    Name= local.table_name
    Environment= var.stage
  }
  
  lifecycle {
    prevent_destroy = true
  }

  depends_on = [
    aws_s3_bucket.rag_s3
  ]
}
