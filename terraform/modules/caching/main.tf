# ====================================
# CACHING MODULE
# Instagram-level caching infrastructure
# Redis ElastiCache for instant feed loading
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
  description = "VPC ID for cache deployment"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for cache deployment"
  type        = list(string)
}

variable "node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.r6g.large"
}

variable "num_cache_nodes" {
  description = "Number of cache nodes"
  type        = number
  default     = 2
}

variable "parameter_group_name" {
  description = "Parameter group name"
  type        = string
  default     = "default.redis7"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# ====================================
# SECURITY GROUP
# ====================================

resource "aws_security_group" "redis" {
  name_prefix = "${var.project_name}-redis-"
  vpc_id      = var.vpc_id
  description = "Security group for Redis ElastiCache cluster"

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"] # Allow from VPC
    description = "Redis access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-redis-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ====================================
# SUBNET GROUP
# ====================================

resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.project_name}-cache-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.project_name}-cache-subnet-group"
  })
}

# ====================================
# PARAMETER GROUP
# Instagram-optimized Redis configuration
# ====================================

resource "aws_elasticache_parameter_group" "redis" {
  family = "redis7.x"
  name   = "${var.project_name}-redis7-params"

  # Instagram-style optimizations for social media feeds
  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru" # Evict least recently used keys when memory is full
  }

  parameter {
    name  = "timeout"
    value = "300" # 5 minutes timeout for idle connections
  }

  parameter {
    name  = "tcp-keepalive"
    value = "60" # Keep connections alive
  }

  parameter {
    name  = "maxclients"
    value = "10000" # High concurrent connections for social media
  }

  # Optimize for read-heavy workloads (Instagram-style feeds)
  parameter {
    name  = "save"
    value = "900 1 300 10 60 10000" # Persistence configuration
  }

  parameter {
    name  = "stop-writes-on-bgsave-error"
    value = "no" # Don't stop writes on background save errors
  }

  tags = var.tags
}

# ====================================
# REPLICATION GROUP (CLUSTER MODE DISABLED)
# For simple use cases with high availability
# ====================================

resource "aws_elasticache_replication_group" "main" {
  replication_group_id         = "${var.project_name}-redis-cluster"
  description                  = "Redis cluster for Breiq caching"
  
  # Instance configuration
  node_type                    = var.node_type
  port                         = 6379
  parameter_group_name         = aws_elasticache_parameter_group.redis.name
  
  # High availability configuration
  num_cache_clusters           = var.num_cache_nodes
  automatic_failover_enabled   = var.num_cache_nodes > 1
  multi_az_enabled            = var.num_cache_nodes > 1
  
  # Network and security
  subnet_group_name           = aws_elasticache_subnet_group.main.name
  security_group_ids          = [aws_security_group.redis.id]
  
  # Data persistence and backup
  snapshot_retention_limit    = 7 # Keep snapshots for 7 days
  snapshot_window             = "05:00-09:00" # Backup during low traffic
  maintenance_window          = "sun:09:00-sun:10:00"
  
  # Security
  at_rest_encryption_enabled  = true
  transit_encryption_enabled  = true
  auth_token                 = random_password.redis_auth.result
  
  # Performance
  apply_immediately          = false
  
  # Notifications
  notification_topic_arn     = aws_sns_topic.cache_alerts.arn
  
  tags = merge(var.tags, {
    Name = "${var.project_name}-redis-cluster"
  })

  lifecycle {
    ignore_changes = [auth_token]
  }
}

# ====================================
# CLUSTER MODE ENABLED (FOR HIGHER SCALE)
# Use this for Instagram-level scaling
# ====================================

resource "aws_elasticache_replication_group" "cluster_mode" {
  count = var.environment == "production" ? 1 : 0
  
  replication_group_id        = "${var.project_name}-redis-cluster-mode"
  description                 = "Redis cluster mode for high-scale caching"
  
  # Cluster configuration
  node_type                   = var.node_type
  port                        = 6379
  parameter_group_name        = "default.redis7.x.cluster.on"
  
  # Cluster mode configuration - Instagram-scale partitioning
  num_node_groups             = 3 # Number of shards
  replicas_per_node_group     = 2 # Replicas per shard for HA
  
  # Network and security
  subnet_group_name           = aws_elasticache_subnet_group.main.name
  security_group_ids          = [aws_security_group.redis.id]
  
  # Data persistence and backup
  snapshot_retention_limit    = 7
  snapshot_window             = "05:00-09:00"
  maintenance_window          = "sun:09:00-sun:10:00"
  
  # Security
  at_rest_encryption_enabled  = true
  transit_encryption_enabled  = true
  auth_token                 = random_password.redis_auth.result
  
  # Performance
  apply_immediately          = false
  
  tags = merge(var.tags, {
    Name = "${var.project_name}-redis-cluster-mode"
  })

  lifecycle {
    ignore_changes = [auth_token]
  }
}

# ====================================
# REDIS AUTH TOKEN
# ====================================

resource "random_password" "redis_auth" {
  length  = 32
  special = false # Redis auth token restrictions
}

# ====================================
# CLOUDWATCH ALARMS FOR MONITORING
# Instagram-level monitoring
# ====================================

resource "aws_cloudwatch_metric_alarm" "cache_cpu" {
  alarm_name          = "${var.project_name}-redis-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors redis cpu utilization"
  alarm_actions       = [aws_sns_topic.cache_alerts.arn]

  dimensions = {
    CacheClusterId = aws_elasticache_replication_group.main.id
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "cache_memory" {
  alarm_name          = "${var.project_name}-redis-memory-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseMemoryUsagePercentage"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "85"
  alarm_description   = "This metric monitors redis memory utilization"
  alarm_actions       = [aws_sns_topic.cache_alerts.arn]

  dimensions = {
    CacheClusterId = aws_elasticache_replication_group.main.id
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "cache_connections" {
  alarm_name          = "${var.project_name}-redis-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CurrConnections"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "5000"
  alarm_description   = "This metric monitors redis connection count"
  alarm_actions       = [aws_sns_topic.cache_alerts.arn]

  dimensions = {
    CacheClusterId = aws_elasticache_replication_group.main.id
  }

  tags = var.tags
}

# ====================================
# SNS TOPIC FOR ALERTS
# ====================================

resource "aws_sns_topic" "cache_alerts" {
  name = "${var.project_name}-cache-alerts"

  tags = var.tags
}

# ====================================
# SECRETS MANAGER FOR REDIS AUTH
# ====================================

resource "aws_secretsmanager_secret" "redis_auth" {
  name        = "${var.project_name}-redis-auth-token"
  description = "Redis authentication token"
  
  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "redis_auth" {
  secret_id = aws_secretsmanager_secret.redis_auth.id
  secret_string = jsonencode({
    auth_token = random_password.redis_auth.result
    endpoint   = aws_elasticache_replication_group.main.primary_endpoint_address
    port       = aws_elasticache_replication_group.main.port
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# ====================================
# MEMCACHED FOR SESSION STORAGE
# Additional caching layer for session data
# ====================================

resource "aws_elasticache_cluster" "memcached" {
  cluster_id           = "${var.project_name}-memcached"
  engine              = "memcached"
  node_type           = "cache.t3.micro"
  num_cache_nodes     = 2
  parameter_group_name = "default.memcached1.6"
  port                = 11211
  subnet_group_name   = aws_elasticache_subnet_group.main.name
  security_group_ids  = [aws_security_group.redis.id]

  tags = merge(var.tags, {
    Name = "${var.project_name}-memcached"
  })
}

# ====================================
# OUTPUTS
# ====================================

output "redis_endpoint" {
  description = "Redis primary endpoint"
  value       = aws_elasticache_replication_group.main.primary_endpoint_address
}

output "redis_reader_endpoint" {
  description = "Redis reader endpoint"
  value       = aws_elasticache_replication_group.main.reader_endpoint_address
}

output "redis_port" {
  description = "Redis port"
  value       = aws_elasticache_replication_group.main.port
}

output "redis_cluster_id" {
  description = "Redis cluster identifier"
  value       = aws_elasticache_replication_group.main.replication_group_id
}

output "memcached_endpoint" {
  description = "Memcached cluster endpoint"
  value       = aws_elasticache_cluster.memcached.cluster_address
}

output "redis_auth_secret_arn" {
  description = "ARN of the Redis auth token secret"
  value       = aws_secretsmanager_secret.redis_auth.arn
}

output "cache_subnet_group_name" {
  description = "Cache subnet group name"
  value       = aws_elasticache_subnet_group.main.name
}

output "cache_security_group_id" {
  description = "Cache security group ID"
  value       = aws_security_group.redis.id
}