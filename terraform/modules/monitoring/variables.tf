# ====================================
# MONITORING MODULE VARIABLES
# ====================================

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

variable "load_balancer_arn" {
  description = "Application Load Balancer ARN for monitoring"
  type        = string
}

variable "ecs_cluster_name" {
  description = "ECS cluster name for monitoring"
  type        = string
}

variable "ecs_service_name" {
  description = "ECS service name for monitoring"
  type        = string
}

variable "cloudfront_distribution_id" {
  description = "CloudFront distribution ID for CDN monitoring"
  type        = string
}

variable "rds_cluster_id" {
  description = "RDS cluster identifier for database monitoring"
  type        = string
}

variable "redis_cluster_id" {
  description = "Redis cluster identifier for cache monitoring"
  type        = string
}

variable "alert_email" {
  description = "Email address for receiving alerts"
  type        = string
  default     = ""
}

variable "alert_phone" {
  description = "Phone number for SMS alerts (optional)"
  type        = string
  default     = ""
}

variable "enable_enhanced_monitoring" {
  description = "Enable enhanced monitoring with additional metrics"
  type        = bool
  default     = false
}

variable "response_time_threshold" {
  description = "Response time threshold in seconds for alerts"
  type        = number
  default     = 2.0
}

variable "error_rate_threshold" {
  description = "Error rate threshold percentage for alerts"
  type        = number
  default     = 5.0
}

variable "cpu_threshold" {
  description = "CPU utilization threshold percentage for alerts"
  type        = number
  default     = 80.0
}

variable "memory_threshold" {
  description = "Memory utilization threshold percentage for alerts"
  type        = number
  default     = 85.0
}

variable "cache_hit_rate_threshold" {
  description = "Cache hit rate threshold percentage for alerts"
  type        = number
  default     = 80.0
}

variable "tags" {
  description = "Tags to apply to all monitoring resources"
  type        = map(string)
  default     = {}
}