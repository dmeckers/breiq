# ====================================
# SQS QUEUES FOR VIDEO PROCESSING
# ====================================

# Main video processing queue
resource "aws_sqs_queue" "video_processing_queue" {
  name                      = "${var.project_name}-${var.environment}-queue"
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 1209600  # 14 days
  receive_wait_time_seconds = 0
  visibility_timeout_seconds = 900     # 15 minutes (matches job timeout)

  # Enable server-side encryption
  kms_master_key_id = "alias/aws/sqs"

  tags = {
    Name        = "${var.project_name}-${var.environment}-queue"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Dead letter queue for failed jobs
resource "aws_sqs_queue" "video_processing_dlq" {
  name                      = "${var.project_name}-${var.environment}-dlq"
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 1209600  # 14 days
  receive_wait_time_seconds = 0

  # Enable server-side encryption
  kms_master_key_id = "alias/aws/sqs"

  tags = {
    Name        = "${var.project_name}-${var.environment}-dlq"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Redrive policy to move failed messages to DLQ
resource "aws_sqs_queue_redrive_policy" "video_processing_redrive" {
  queue_url = aws_sqs_queue.video_processing_queue.id
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.video_processing_dlq.arn
    maxReceiveCount     = 3
  })
}

# AI moderation queue (separate from main processing)
resource "aws_sqs_queue" "ai_moderation_queue" {
  name                      = "${var.project_name}-${var.environment}-ai-moderation"
  delay_seconds             = 30        # 30 second delay for AI processing
  max_message_size          = 262144
  message_retention_seconds = 1209600   # 14 days
  receive_wait_time_seconds = 0
  visibility_timeout_seconds = 300      # 5 minutes for AI processing

  # Enable server-side encryption
  kms_master_key_id = "alias/aws/sqs"

  tags = {
    Name        = "${var.project_name}-${var.environment}-ai-moderation"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Output the queue URLs for Laravel configuration
output "sqs_queue_url" {
  description = "Main SQS queue URL for video processing"
  value       = aws_sqs_queue.video_processing_queue.id
}

output "sqs_queue_name" {
  description = "Main SQS queue name"
  value       = aws_sqs_queue.video_processing_queue.name
}

output "sqs_dlq_url" {
  description = "Dead letter queue URL"
  value       = aws_sqs_queue.video_processing_dlq.id
}

output "ai_moderation_queue_url" {
  description = "AI moderation queue URL"
  value       = aws_sqs_queue.ai_moderation_queue.id
}

output "sqs_region" {
  description = "AWS region for SQS queues"
  value       = var.aws_region
}

output "sqs_prefix" {
  description = "SQS URL prefix for Laravel configuration"
  value       = "https://sqs.${var.aws_region}.amazonaws.com/${data.aws_caller_identity.current.account_id}"
}

# Data source to get current AWS account ID
# Note: aws_caller_identity "current" is already defined in main.tf
