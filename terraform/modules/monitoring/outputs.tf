# ====================================
# MONITORING MODULE OUTPUTS
# ====================================

output "dashboard_url" {
  description = "URL of the main CloudWatch dashboard"
  value       = "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "dashboard_name" {
  description = "Name of the main CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "alerts_topic_arn" {
  description = "ARN of the general alerts SNS topic"
  value       = aws_sns_topic.alerts.arn
}

output "critical_alerts_topic_arn" {
  description = "ARN of the critical alerts SNS topic"
  value       = aws_sns_topic.critical_alerts.arn
}

output "app_health_alarm_name" {
  description = "Name of the composite application health alarm"
  value       = aws_cloudwatch_composite_alarm.app_health.alarm_name
}

output "app_health_alarm_arn" {
  description = "ARN of the composite application health alarm"
  value       = aws_cloudwatch_composite_alarm.app_health.arn
}

output "alarm_names" {
  description = "List of all alarm names created"
  value = [
    aws_cloudwatch_metric_alarm.high_response_time.alarm_name,
    aws_cloudwatch_metric_alarm.high_4xx_errors.alarm_name,
    aws_cloudwatch_metric_alarm.high_5xx_errors.alarm_name,
    aws_cloudwatch_metric_alarm.ecs_high_cpu.alarm_name,
    aws_cloudwatch_metric_alarm.ecs_high_memory.alarm_name,
    aws_cloudwatch_metric_alarm.cdn_high_error_rate.alarm_name,
    aws_cloudwatch_metric_alarm.cdn_origin_latency.alarm_name,
    aws_cloudwatch_metric_alarm.rds_high_cpu.alarm_name,
    aws_cloudwatch_metric_alarm.rds_high_connections.alarm_name,
    aws_cloudwatch_metric_alarm.rds_read_latency.alarm_name,
    aws_cloudwatch_metric_alarm.redis_high_cpu.alarm_name,
    aws_cloudwatch_metric_alarm.redis_low_cache_hit_rate.alarm_name,
    aws_cloudwatch_metric_alarm.slow_video_processing.alarm_name
  ]
}

output "log_groups" {
  description = "List of CloudWatch log groups created"
  value = [
    aws_cloudwatch_log_group.app_metrics.name
  ]
}