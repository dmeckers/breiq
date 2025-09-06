# ====================================
# DATABASE MODULE
# Instagram-level database infrastructure
# RDS Aurora + DocumentDB for optimal performance
# ====================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ====================================
# VARIABLES
# ====================================

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for database deployment"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for database deployment"
  type        = list(string)
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.r6g.large"
}

variable "backup_retention" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# ====================================
# DATA SOURCES
# ====================================

data "aws_availability_zones" "available" {
  state = "available"
}

# ====================================
# SECURITY GROUPS
# ====================================

resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-rds-"
  vpc_id      = var.vpc_id
  description = "Security group for RDS Aurora cluster"

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"] # Allow from VPC
    description = "MySQL/Aurora access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-rds-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "documentdb" {
  name_prefix = "${var.project_name}-docdb-"
  vpc_id      = var.vpc_id
  description = "Security group for DocumentDB cluster"

  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"] # Allow from VPC
    description = "DocumentDB access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-documentdb-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ====================================
# SUBNET GROUPS
# ====================================

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.project_name}-db-subnet-group"
  })
}

resource "aws_docdb_subnet_group" "main" {
  name       = "${var.project_name}-docdb-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.project_name}-docdb-subnet-group"
  })
}

# ====================================
# PARAMETER GROUPS
# ====================================

# Aurora MySQL parameter group optimized for Instagram-style workloads
resource "aws_rds_cluster_parameter_group" "main" {
  name        = "${var.project_name}-aurora-mysql80"
  family      = "aurora-mysql8.0"
  description = "Custom parameter group for Aurora MySQL optimized for social media workloads"

  # Optimizations for high-read workloads (Instagram-style feeds)
  parameter {
    name  = "innodb_buffer_pool_size"
    value = "75" # 75% of available memory
  }

  parameter {
    name  = "query_cache_type"
    value = "1" # Enable query cache
  }

  parameter {
    name  = "query_cache_size"
    value = "67108864" # 64MB query cache
  }

  parameter {
    name  = "max_connections"
    value = "5000" # High connection limit for social media app
  }

  parameter {
    name  = "innodb_flush_log_at_trx_commit"
    value = "2" # Better performance for social media writes
  }

  parameter {
    name  = "slow_query_log"
    value = "1" # Enable slow query logging
  }

  parameter {
    name  = "long_query_time"
    value = "1" # Log queries taking more than 1 second
  }

  tags = var.tags
}

# DocumentDB parameter group optimized for metadata and analytics
resource "aws_docdb_cluster_parameter_group" "main" {
  name        = "${var.project_name}-docdb-params"
  family      = "docdb5.0"
  description = "Custom parameter group for DocumentDB optimized for analytics"

  parameter {
    name  = "audit_logs"
    value = "enabled"
  }

  parameter {
    name  = "profiler"
    value = "enabled"
  }

  parameter {
    name  = "profiler_threshold_ms"
    value = "100"
  }

  tags = var.tags
}

# ====================================
# RDS AURORA CLUSTER
# Primary database for user data, moves, videos, etc.
# ====================================

resource "random_password" "rds_password" {
  length  = 32
  special = true
}

resource "aws_rds_cluster" "main" {
  cluster_identifier                  = "${var.project_name}-aurora-cluster"
  engine                             = "aurora-mysql"
  engine_version                     = "8.0.mysql_aurora.3.05.2"
  database_name                      = "breiq"
  master_username                    = "breiq_admin"
  master_password                    = random_password.rds_password.result
  manage_master_user_password        = false
  
  # High availability and performance
  backup_retention_period            = var.backup_retention
  preferred_backup_window            = "03:00-04:00"
  preferred_maintenance_window       = "sun:04:00-sun:05:00"
  
  # Network and security
  vpc_security_group_ids             = [aws_security_group.rds.id]
  db_subnet_group_name               = aws_db_subnet_group.main.name
  db_cluster_parameter_group_name    = aws_rds_cluster_parameter_group.main.name
  
  # Performance and monitoring
  enabled_cloudwatch_logs_exports    = ["audit", "error", "general", "slowquery"]
  monitoring_interval               = 60
  performance_insights_enabled      = true
  performance_insights_retention_period = 7
  
  # Security
  storage_encrypted                  = true
  copy_tags_to_snapshot             = true
  deletion_protection               = var.environment == "production"
  
  # Backtrack for point-in-time recovery (Instagram-level data safety)
  backtrack_window                  = 72 # 72 hours
  
  tags = merge(var.tags, {
    Name = "${var.project_name}-aurora-cluster"
  })

  lifecycle {
    ignore_changes = [master_password]
  }
}

# Aurora cluster instances (writer + readers for Instagram-level read scaling)
resource "aws_rds_cluster_instance" "cluster_instances" {
  count              = 3 # 1 writer + 2 readers for high availability
  identifier         = "${var.project_name}-aurora-${count.index}"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = var.instance_class
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version
  
  # Performance monitoring
  performance_insights_enabled = true
  monitoring_interval         = 60
  
  # Auto minor version updates during maintenance window
  auto_minor_version_upgrade = true
  
  tags = merge(var.tags, {
    Name = "${var.project_name}-aurora-instance-${count.index}"
    Role = count.index == 0 ? "writer" : "reader"
  })
}

# ====================================
# DOCUMENTDB CLUSTER
# For video metadata, analytics, and real-time data
# ====================================

resource "random_password" "docdb_password" {
  length  = 32
  special = false # DocumentDB doesn't support all special characters
}

resource "aws_docdb_cluster" "main" {
  cluster_identifier              = "${var.project_name}-docdb-cluster"
  engine                         = "docdb"
  engine_version                 = "5.0.0"
  master_username                = "breiq_docdb"
  master_password                = random_password.docdb_password.result
  
  # High availability
  backup_retention_period        = var.backup_retention
  preferred_backup_window        = "07:00-09:00" # Different from RDS to spread load
  preferred_maintenance_window   = "sun:09:00-sun:10:00"
  
  # Network and security
  vpc_security_group_ids         = [aws_security_group.documentdb.id]
  db_subnet_group_name           = aws_docdb_subnet_group.main.name
  db_cluster_parameter_group_name = aws_docdb_cluster_parameter_group.main.name
  
  # Performance and monitoring
  enabled_cloudwatch_logs_exports = ["audit", "profiler"]
  
  # Security
  storage_encrypted              = true
  kms_key_id                    = aws_kms_key.docdb.arn
  deletion_protection           = var.environment == "production"
  
  # Skip final snapshot for non-production
  skip_final_snapshot           = var.environment != "production"
  final_snapshot_identifier     = var.environment == "production" ? "${var.project_name}-docdb-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}" : null
  
  tags = merge(var.tags, {
    Name = "${var.project_name}-docdb-cluster"
  })

  lifecycle {
    ignore_changes = [master_password]
  }
}

# DocumentDB cluster instances
resource "aws_docdb_cluster_instance" "cluster_instances" {
  count              = 2 # 2 instances for high availability
  identifier         = "${var.project_name}-docdb-${count.index}"
  cluster_identifier = aws_docdb_cluster.main.id
  instance_class     = "db.t4g.medium" # Start smaller for DocumentDB
  
  # Auto minor version updates
  auto_minor_version_upgrade = true
  
  tags = merge(var.tags, {
    Name = "${var.project_name}-docdb-instance-${count.index}"
  })
}

# KMS key for DocumentDB encryption
resource "aws_kms_key" "docdb" {
  description             = "KMS key for DocumentDB encryption"
  deletion_window_in_days = 7
  
  tags = merge(var.tags, {
    Name = "${var.project_name}-docdb-kms-key"
  })
}

resource "aws_kms_alias" "docdb" {
  name          = "alias/${var.project_name}-docdb"
  target_key_id = aws_kms_key.docdb.key_id
}

# ====================================
# SECRETS MANAGER FOR DATABASE CREDENTIALS
# ====================================

resource "aws_secretsmanager_secret" "rds_credentials" {
  name        = "${var.project_name}-rds-credentials"
  description = "RDS Aurora cluster credentials"
  
  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "rds_credentials" {
  secret_id = aws_secretsmanager_secret.rds_credentials.id
  secret_string = jsonencode({
    username = aws_rds_cluster.main.master_username
    password = random_password.rds_password.result
    endpoint = aws_rds_cluster.main.endpoint
    port     = aws_rds_cluster.main.port
    database = aws_rds_cluster.main.database_name
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_secretsmanager_secret" "docdb_credentials" {
  name        = "${var.project_name}-docdb-credentials"
  description = "DocumentDB cluster credentials"
  
  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "docdb_credentials" {
  secret_id = aws_secretsmanager_secret.docdb_credentials.id
  secret_string = jsonencode({
    username = aws_docdb_cluster.main.master_username
    password = random_password.docdb_password.result
    endpoint = aws_docdb_cluster.main.endpoint
    port     = aws_docdb_cluster.main.port
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# ====================================
# OUTPUTS
# ====================================

output "rds_endpoint" {
  description = "RDS Aurora cluster endpoint"
  value       = aws_rds_cluster.main.endpoint
}

output "rds_reader_endpoint" {
  description = "RDS Aurora cluster reader endpoint"
  value       = aws_rds_cluster.main.reader_endpoint
}

output "rds_cluster_id" {
  description = "RDS Aurora cluster identifier"
  value       = aws_rds_cluster.main.cluster_identifier
}

output "documentdb_endpoint" {
  description = "DocumentDB cluster endpoint"
  value       = aws_docdb_cluster.main.endpoint
}

output "documentdb_cluster_id" {
  description = "DocumentDB cluster identifier"
  value       = aws_docdb_cluster.main.cluster_identifier
}

output "rds_credentials_secret_arn" {
  description = "ARN of the RDS credentials secret"
  value       = aws_secretsmanager_secret.rds_credentials.arn
}

output "docdb_credentials_secret_arn" {
  description = "ARN of the DocumentDB credentials secret"
  value       = aws_secretsmanager_secret.docdb_credentials.arn
}