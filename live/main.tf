provider "aws" {
  region = "us-west-2"  # Change this to your desired region
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "bedrock-poc-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

module "aurora_serverless" {
  source = "../modules/database"

  cluster_identifier = "my-aurora-serverless"
  vpc_id             = module.vpc.vpc_id 
  subnet_ids         = module.vpc.private_subnets

  # Optionally override other defaults
  database_name    = "myapp"
  master_username  = "dbadmin"
  max_capacity     = 1
  min_capacity     = 0.5
  allowed_cidr_blocks = ["10.0.0.0/16"]   
}

module "bedrock_kb" {
  source = "../modules/bedrock_kb"  # Make sure this path is correct

  knowledge_base_name        = "my-bedrock-kb"
  knowledge_base_description = "Knowledge base connected to Aurora Serverless database"

  aurora_arn        = module.aurora_serverless.database_arn
  aurora_db_name    = module.aurora_serverless.database_name
  aurora_endpoint   = module.aurora_serverless.cluster_endpoint
  aurora_table_name = "bedrock_integration.bedrock_kb"
  aurora_primary_key_field = "id"
  aurora_metadata_field = "metadata"
  aurora_text_field = "chunks"
  aurora_verctor_field = "embedding"
  aurora_username   = module.aurora_serverless.database_master_username
  aurora_secret_arn = module.aurora_serverless.database_secretsmanager_secret_arn
}

data "aws_caller_identity" "current" {}

locals {
  bucket_name = "bedrock-kb-${data.aws_caller_identity.current.account_id}"
}

module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.0"

  bucket = local.bucket_name
  acl    = "private"

  control_object_ownership = true
  object_ownership         = "BucketOwnerPreferred"

  versioning = {
    enabled = true
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}