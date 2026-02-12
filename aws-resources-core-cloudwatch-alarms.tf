resource "aws_cloudwatch_metric_alarm" "msk_disk_usage_high" {
  alarm_name          = "${var.project_name}-msk-${var.environment}-disk-usage-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "KafkaDataLogsDiskUsed"
  namespace           = "AWS/Kafka"
  period              = 300
  statistic           = "Maximum"
  threshold           = 80
  alarm_description   = "MSK disk usage > 80%"
  treat_missing_data  = "missing"

  dimensions = {
    ClusterName = aws_msk_cluster.cloudlake_msk.cluster_name
  }

  alarm_actions = [aws_sns_topic.msk_alerts.arn] # optional: SNS topic for alerts
}

resource "aws_cloudwatch_metric_alarm" "msk_memory_util" {
  alarm_name          = "${var.project_name}-msk-${var.environment}-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "KafkaBrokerMemoryUtilization"
  namespace           = "AWS/Kafka"
  period              = 300
  statistic           = "Maximum"
  threshold           = 85
  alarm_description   = "MSK broker memory utilization > 85%"
  treat_missing_data  = "missing"

  dimensions = {
    ClusterName = aws_msk_cluster.cloudlake_msk.cluster_name
  }

  alarm_actions = [aws_sns_topic.msk_alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "msk_cpu_util" {
  alarm_name          = "${var.project_name}-msk-${var.environment}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/Kafka"
  period              = 300
  statistic           = "Maximum"
  threshold           = 80
  alarm_description   = "MSK CPU > 80%"
  treat_missing_data  = "missing"

  dimensions = {
    ClusterName = aws_msk_cluster.cloudlake_msk.cluster_name
  }

  alarm_actions = [aws_sns_topic.msk_alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "msk_idle_thread" {
  alarm_name          = "${var.project_name}-msk-${var.environment}-low-idle-thread"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "KafkaRequestHandlerAvgIdlePercent"
  namespace           = "AWS/Kafka"
  period              = 300
  statistic           = "Average"
  threshold           = 20
  alarm_description   = "MSK handler thread idle < 20%"
  treat_missing_data  = "missing"

  dimensions = {
    ClusterName = aws_msk_cluster.cloudlake_msk.cluster_name
  }

  alarm_actions = [aws_sns_topic.msk_alerts.arn]
}


# SNS Topic for alerts
resource "aws_sns_topic" "msk_alerts" {
  name = "${var.project_name}-msk-alerts-${var.environment}"
}

# SNS Email Subscription
resource "aws_sns_topic_subscription" "email_msk_subscription_admin_1" {
  topic_arn = aws_sns_topic.msk_alerts.arn
  protocol  = "email"
  endpoint  = "msegura@rcp.pe" 
}

# SNS Email Subscription
resource "aws_sns_topic_subscription" "email_msk_subscription_admin_2" {
  topic_arn = aws_sns_topic.msk_alerts.arn
  protocol  = "email"
  endpoint  = "cparada@rcp.pe" 
}

# SNS Email Subscription
resource "aws_sns_topic_subscription" "email_msk_subscription_admin_3" {
  topic_arn = aws_sns_topic.msk_alerts.arn
  protocol  = "email"
  endpoint  = "dgarcia@rcp.pe" 
}

# SNS Email Subscription
resource "aws_sns_topic_subscription" "email_msk_subscription_admin_4" {
  topic_arn = aws_sns_topic.msk_alerts.arn
  protocol  = "email"
  endpoint  = "jllontop@rcp.pe" 
}