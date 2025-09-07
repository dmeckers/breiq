# ====================================
# BREIQ TERRAFORM VARIABLES
# ====================================

variable "aws_region" {
  description = "Primary AWS region for Breiq infrastructure"
  type        = string
  default     = "us-east-1"
  
  validation {
    condition = contains([
      "us-east-1", "us-east-2", "us-west-1", "us-west-2",
      "eu-west-1", "eu-west-2", "eu-central-1",
      "ap-southeast-1", "ap-southeast-2", "ap-northeast-1"
    ], var.aws_region)
    error_message = "AWS region must be a valid region for global mobile app delivery."
  }
}

variable "aws_profile" {
  description = "AWS CLI profile to use (for multi-account setup)"
  type        = string
  default     = "breiq"
  
  validation {
    condition     = length(var.aws_profile) > 0
    error_message = "AWS profile name cannot be empty."
  }
}

variable "environment" {
  description = "Environment name (staging/production)"
  type        = string
  default     = "production"
  
  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "Environment must be either 'staging' or 'production'."
  }
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "breiq"
  
  validation {
    condition     = length(var.project_name) >= 3 && length(var.project_name) <= 20
    error_message = "Project name must be between 3 and 20 characters."
  }
}

variable "domain_name" {
  description = "Primary domain name for the platform"
  type        = string
  default     = "breiq.online"
}

variable "enable_multi_region" {
  description = "Enable multi-region deployment for global performance"
  type        = bool
  default     = false # Start with single region, expand later
}

variable "mobile_app_origins" {
  description = "Allowed origins for mobile app API access"
  type        = list(string)
  default     = [
    "https://breiq.online",
    "app://breiq",
    "https://breiq-admin.online"
  ]
}

variable "video_bucket_cors_origins" {
  description = "CORS origins for video bucket access"
  type        = list(string)
  default     = [
    "https://breiq.online",
    "app://breiq"
  ]
}

# Database Configuration
variable "db_instance_class" {
  description = "RDS instance class for PostgreSQL"
  type        = string
  default     = "db.t4g.medium" # Start small, scale up as needed
  
  validation {
    condition = contains([
      "db.t4g.micro", "db.t4g.small", "db.t4g.medium", "db.t4g.large",
      "db.r6g.large", "db.r6g.xlarge", "db.r6g.2xlarge"
    ], var.db_instance_class)
    error_message = "Database instance class must be a valid ARM-based instance type."
  }
}

variable "db_backup_retention_days" {
  description = "Number of days to retain database backups"
  type        = number
  default     = 7 # 7 days for production, can be reduced for staging
  
  validation {
    condition     = var.db_backup_retention_days >= 1 && var.db_backup_retention_days <= 35
    error_message = "Backup retention must be between 1 and 35 days."
  }
}

variable "db_multi_az" {
  description = "Enable Multi-AZ deployment for RDS"
  type        = bool
  default     = false # Start single-AZ, enable for production scaling
}

# Caching Configuration
variable "cache_node_type" {
  description = "ElastiCache Redis node type"
  type        = string
  default     = "cache.t4g.micro" # Start small
  
  validation {
    condition = contains([
      "cache.t4g.micro", "cache.t4g.small", "cache.t4g.medium",
      "cache.r6g.large", "cache.r6g.xlarge"
    ], var.cache_node_type)
    error_message = "Cache node type must be a valid Redis node type."
  }
}

variable "cache_num_nodes" {
  description = "Number of cache nodes"
  type        = number
  default     = 1 # Start with single node
  
  validation {
    condition     = var.cache_num_nodes >= 1 && var.cache_num_nodes <= 6
    error_message = "Number of cache nodes must be between 1 and 6."
  }
}

# ECS Configuration
variable "ecs_cpu" {
  description = "CPU units for ECS tasks (256, 512, 1024, etc.)"
  type        = number
  default     = 512 # Start smaller for cost efficiency
  
  validation {
    condition = contains([256, 512, 1024, 2048, 4096], var.ecs_cpu)
    error_message = "ECS CPU must be a valid Fargate CPU value."
  }
}

variable "ecs_memory" {
  description = "Memory (MB) for ECS tasks"
  type        = number
  default     = 1024 # 1GB memory
  
  validation {
    condition     = var.ecs_memory >= 512 && var.ecs_memory <= 8192
    error_message = "ECS memory must be between 512MB and 8GB."
  }
}

variable "ecs_desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 2 # Start with 2 tasks for availability
  
  validation {
    condition     = var.ecs_desired_count >= 1 && var.ecs_desired_count <= 10
    error_message = "ECS desired count must be between 1 and 10."
  }
}

variable "ecs_min_capacity" {
  description = "Minimum number of ECS tasks for auto scaling"
  type        = number
  default     = 1
}

variable "ecs_max_capacity" {
  description = "Maximum number of ECS tasks for auto scaling"
  type        = number
  default     = 10
}

# Monitoring and Alerting
variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring"
  type        = bool
  default     = true
}

variable "alert_email" {
  description = "Email address for CloudWatch alerts"
  type        = string
  default     = "alerts@breiq.online"
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.alert_email))
    error_message = "Alert email must be a valid email address."
  }
}

# Security
variable "enable_waf" {
  description = "Enable AWS WAF for API protection"
  type        = bool
  default     = true
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access resources (empty = all)"
  type        = list(string)
  default     = [] # Allow all by default, restrict in production
}

# Tags
variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}