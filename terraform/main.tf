# ====================================
# BREIQ INSTAGRAM REELS ARCHITECTURE
# Complete Terraform Infrastructure as Code
# ====================================

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4"
    }
  }
}

# ====================================
# PROVIDER CONFIGURATION
# ====================================

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "breiq"
      Environment = var.environment
      ManagedBy   = "terraform"
      Purpose     = "instagram-reels-architecture"
    }
  }
}

# ====================================
# VARIABLES
# ====================================

variable "aws_region" {
  description = "Primary AWS region"
  type        = string
  default     = "us-east-1" # Best for global CloudFront performance
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "breiq"
}

variable "domain_name" {
  description = "Primary domain name"
  type        = string
  default     = "breiq.online"
}

variable "enable_multi_region" {
  description = "Enable multi-region deployment for global performance"
  type        = bool
  default     = true
}

variable "video_bucket_cors_origins" {
  description = "CORS origins for video bucket"
  type        = list(string)
  default     = ["https://breiq.online", "https://www.breiq.online", "https://app.breiq.online"]
}

# ====================================
# LOCALS
# ====================================

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
  }

  # Multi-region support for Instagram-level performance
  regions = var.enable_multi_region ? [
    "us-east-1",    # North America East
    "us-west-2",    # North America West  
    "eu-west-1",    # Europe
    "ap-southeast-1" # Asia Pacific
  ] : [var.aws_region]

  # Video quality profiles (like Instagram)
  video_profiles = {
    mobile_low = {
      width  = 480
      height = 854
      bitrate = "500k"
    }
    mobile_standard = {
      width  = 720
      height = 1280
      bitrate = "1500k"
    }
    hd = {
      width  = 1080
      height = 1920
      bitrate = "3000k"
    }
  }
}

# ====================================
# DATA SOURCES
# ====================================

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# ====================================
# RANDOM IDENTIFIERS
# ====================================

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# ====================================
# MAIN INFRASTRUCTURE MODULES
# ====================================

# 1. Video Storage and CDN System
module "video_delivery" {
  source = "./modules/video-delivery"

  project_name     = var.project_name
  environment      = var.environment
  bucket_suffix    = random_string.bucket_suffix.result
  cors_origins     = var.video_bucket_cors_origins
  video_profiles   = local.video_profiles
  
  tags = local.common_tags
}

# 2. Database Infrastructure (Aurora + DocumentDB)
module "database" {
  source = "./modules/database"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.networking.vpc_id
  subnet_ids   = module.networking.private_subnet_ids
  
  # Instagram-level database configuration
  instance_class     = "db.r6g.xlarge"  # High performance for feeds
  backup_retention   = 30               # Long backup retention
  multi_az          = true              # High availability
  
  tags = local.common_tags
}

# 3. Caching Infrastructure (Redis/ElastiCache)
module "caching" {
  source = "./modules/caching"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.networking.vpc_id
  subnet_ids   = module.networking.private_subnet_ids
  
  # Instagram-level caching for feeds
  node_type          = "cache.r6g.xlarge"
  num_cache_nodes    = 3
  parameter_group_name = "default.redis7"
  
  tags = local.common_tags
}

# 4. Networking Infrastructure
module "networking" {
  source = "./modules/networking"

  project_name = var.project_name
  environment  = var.environment
  
  # High availability across multiple AZs
  availability_zones = data.aws_availability_zones.available.names
  
  tags = local.common_tags
}

# 5. Application Infrastructure (ECS/Lambda)
module "application" {
  source = "./modules/application"

  project_name     = var.project_name
  environment      = var.environment
  vpc_id          = module.networking.vpc_id
  subnet_ids      = module.networking.private_subnet_ids
  public_subnet_ids = module.networking.public_subnet_ids
  
  # Reference to other resources
  video_bucket_name    = module.video_delivery.video_bucket_name
  cloudfront_domain    = module.video_delivery.cloudfront_domain
  database_endpoint    = module.database.rds_endpoint
  redis_endpoint       = module.caching.redis_endpoint
  
  tags = local.common_tags
}

# 6. Monitoring and Analytics
module "monitoring" {
  source = "./modules/monitoring"

  project_name = var.project_name
  environment  = var.environment
  
  # Resources to monitor
  cloudfront_distribution_id = module.video_delivery.cloudfront_distribution_id
  rds_cluster_id            = module.database.rds_cluster_id
  redis_cluster_id          = module.caching.redis_cluster_id
  
  tags = local.common_tags
}

# ====================================
# OUTPUTS
# ====================================

output "video_delivery_endpoints" {
  description = "Video delivery system endpoints"
  value = {
    cloudfront_domain = module.video_delivery.cloudfront_domain
    s3_bucket_name   = module.video_delivery.video_bucket_name
    api_endpoint     = module.application.api_gateway_endpoint
  }
}

output "database_endpoints" {
  description = "Database connection endpoints"
  value = {
    rds_endpoint     = module.database.rds_endpoint
    documentdb_endpoint = module.database.documentdb_endpoint
    redis_endpoint   = module.caching.redis_endpoint
  }
  sensitive = true
}

output "application_endpoints" {
  description = "Application endpoints"
  value = {
    load_balancer_dns = module.application.load_balancer_dns
    api_gateway_url   = module.application.api_gateway_endpoint
  }
}

output "deployment_info" {
  description = "Deployment information"
  value = {
    region      = var.aws_region
    environment = var.environment
    project     = var.project_name
    timestamp   = timestamp()
  }
}