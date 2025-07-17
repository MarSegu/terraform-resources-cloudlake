# SNS Topic for alerts
resource "aws_sns_topic" "budget_alerts" {
  name = "${var.project_name}-budget-alerts-topic-${var.environment}"
}

# SNS Email Subscription
resource "aws_sns_topic_subscription" "email_subscription_admin_1" {
  topic_arn = aws_sns_topic.budget_alerts.arn
  protocol  = "email"
  endpoint  = "msegura@rcp.pe" 
}

# SNS Email Subscription
resource "aws_sns_topic_subscription" "email_subscription_admin_2" {
  topic_arn = aws_sns_topic.budget_alerts.arn
  protocol  = "email"
  endpoint  = "cparada@rcp.pe" 
}

# SNS Email Subscription
resource "aws_sns_topic_subscription" "email_subscription_admin_3" {
  topic_arn = aws_sns_topic.budget_alerts.arn
  protocol  = "email"
  endpoint  = "dgarcia@rcp.pe" 
}

# SNS Email Subscription
resource "aws_sns_topic_subscription" "email_subscription_admin_3" {
  topic_arn = aws_sns_topic.budget_alerts.arn
  protocol  = "email"
  endpoint  = "jllontop@rcp.pe" 
}

# IAM Role for AWS Budgets to publish to SNS
resource "aws_iam_role" "budgets_role" {
  name = "AWSBudgetsSNSRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "budgets.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# IAM Policy for AWS Budgets to publish to SNS
resource "aws_iam_policy" "budgets_policy" {
  name        = "AWSBudgetsSNSPolicy"
  description = "Policy for AWS Budgets to send notifications to SNS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sns:Publish"
      Resource = aws_sns_topic.budget_alerts.arn
    }]
  })
}

# Attach Policy to Role
resource "aws_iam_role_policy_attachment" "budgets_role_attach" {
  role       = aws_iam_role.budgets_role.name
  policy_arn = aws_iam_policy.budgets_policy.arn
}

# AWS Budget (Alerts when cost exceeds $5)
resource "aws_budgets_budget" "monthly_budget" {
  name         = "MonthlyBudget"
  budget_type  = "COST"
  limit_amount = "800.00"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 40 # 40% of budget
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = ["msegura@rcp.pe","cparada@rcp.pe","dgarcia@rcp.pe","jllontop@rcp.pe"] 
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100 # 100% of budget
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = ["msegura@rcp.pe", "cparada@rcp.pe","dgarcia@rcp.pe","jllontop@rcp.pe"]
  }
}