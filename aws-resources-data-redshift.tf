# Security Group for Redshift
resource "aws_security_group" "redshift_sg" {
  name        = "${var.project_name}-redshift-sg-${var.environment}"
  description = "Security group for Redshift cluster"
  vpc_id      = aws_vpc.cloudlake_data_vpc.id

  # Allow Redshift port (default 5439) from anywhere
  ingress {
    from_port   = 5439
    to_port     = 5439
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags

}

# Redshift Subnet Group 
resource "aws_redshift_subnet_group" "redshift_subnet_group" {
  name        = "${var.project_name}-redshift-subnet-group-${var.environment}"
  description = "Subnet group for Redshift cluster"

  subnet_ids = [
    aws_subnet.private_subnet_data_az2.id,
  ]
  tags = var.tags
}

# Create the Redshift Cluster
resource "aws_redshift_cluster" "data_logs_cluster" {
  cluster_identifier = "${var.project_name}-data-logs-cluster-${var.environment}"

  node_type       = "dc2.large"
  number_of_nodes = 1 # Single-node

  database_name   = "${var.project_name}_redshift_db_${var.environment}"
  master_username = var.redshift_db_username
  master_password = var.redshift_db_password

  vpc_security_group_ids    = [aws_security_group.redshift_sg.id]
  cluster_subnet_group_name = aws_redshift_subnet_group.redshift_subnet_group.name

  publicly_accessible       = true
  final_snapshot_identifier = "data-logs-cluster-final-snapshot-${var.environment}-${time_static.redshift_snapshot.unix}"

  lifecycle {
    ignore_changes = [
      maintenance_track_name
    ]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-data-logs-cluster-${var.environment}"
    }
  )
}

resource "time_static" "redshift_snapshot" {}

#Cloudwatch

resource "aws_cloudwatch_metric_alarm" "redshift_cpu_alarm" {
  alarm_name          = "${var.project_name}-redshift-cpu-high-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/Redshift"
  period              = "300"
  statistic           = "Average"
  threshold           = 80

  alarm_description = "Triggers if Redshift CPU usage exceeds 80%"

  dimensions = {
    ClusterIdentifier = aws_redshift_cluster.data_logs_cluster.cluster_identifier
  }

  treat_missing_data = "notBreaching"
}