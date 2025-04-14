resource "aws_msk_cluster" "cloudlake_msk" {
  cluster_name           = "${var.project_name}-msk-${var.environment}"
  kafka_version          = "3.4.0"
  number_of_broker_nodes = 3

  broker_node_group_info {
    instance_type = "kafka.t3.small"
    client_subnets = [
      aws_subnet.private_az1.id,
      aws_subnet.private_az2.id,
      aws_subnet.private_az3.id
    ]
    security_groups = [aws_security_group.msk_sg.id]
    storage_info {
      ebs_storage_info {
        volume_size = 10
      }
    }
  }

  encryption_info {
    encryption_in_transit {
      client_broker = "TLS"
      in_cluster    = true
    }
  }

  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = true
        log_group = aws_cloudwatch_log_group.msk_cloudwatch.name
      }
    }
  }

  tags = var.tags
}

resource "aws_security_group" "msk_sg" {
  name        = "cloudlake-msk-sg-${var.environment}"
  description = "Security group for MSK cluster"
  vpc_id      = aws_vpc.cloudlake_core.id

  # Allow inbound traffic from within the VPC (e.g., MSK Connect, EC2, etc.)
  ingress {
    description = "Allow Kafka traffic over TLS from VPC"
    from_port   = 9094
    to_port     = 9094
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.cloudlake_core.cidr_block]
  }

  # Allow MSK to talk to itself (brokers to brokers, etc.)
  ingress {
    description = "Internal broker-to-broker communication"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  # Egress: allow all outbound traffic (default behavior)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "msk_cloudwatch" {
  name = "${var.project_name}_msk_broker_logs_${var.environment}"
}

resource "aws_iam_role" "msk_connect_execution_role" {
  name = "${var.project_name}-msk-connect-execution-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Principal = {
        Service = "kafkaconnect.amazonaws.com"
      }
      Effect = "Allow"
    }]
  })
}

resource "aws_iam_role_policy" "msk_connect_execution_policy" {
  name = "${var.project_name}-msk-connect-permissions-${var.environment}"
  role = aws_iam_role.msk_connect_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.plugin_bucket.arn,
          "${aws_s3_bucket.plugin_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kafka-cluster:Connect",
          "kafka-cluster:DescribeCluster",
          "kafka-cluster:DescribeConfiguration",
          "kafka-cluster:GetBootstrapBrokers",
          "kafka-cluster:DescribeClusterVpcConnection"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_mskconnect_connector" "cloudlake_connector" {
  name                       = "${var.project_name}-msk-connector-${var.environment}"
  kafkaconnect_version       = "2.7.1"
  service_execution_role_arn = aws_iam_role.msk_connect_execution_role.arn

  kafka_cluster {
    apache_kafka_cluster {
      bootstrap_servers = aws_msk_cluster.cloudlake_msk.bootstrap_brokers_tls
      vpc {
        security_groups = [aws_security_group.msk_sg.id]
        subnets = [
          aws_subnet.private_az1.id,
          aws_subnet.private_az2.id
        ]
      }
    }
  }

  kafka_cluster_client_authentication {
    authentication_type = "NONE" # or IAM/SASL if using auth
  }

  kafka_cluster_encryption_in_transit {
    encryption_type = "TLS"
  }

  connector_configuration = {
    "connector.class"                = "io.confluent.connect.s3.S3SinkConnector"
    "tasks.max"                      = "1"
    "topics"                         = "your-kafka-topic"
    "s3.bucket.name"                 = aws_s3_bucket.raw_data_bucket.bucket
    "s3.region"                      = var.aws_region
    "flush.size"                     = "1"
    "storage.class"                  = "io.confluent.connect.s3.storage.S3Storage"
    "format.class"                   = "io.confluent.connect.s3.format.json.JsonFormat"
    "partitioner.class"              = "io.confluent.connect.storage.partitioner.DefaultPartitioner"
    "value.converter"                = "org.apache.kafka.connect.json.JsonConverter"
    "value.converter.schemas.enable" = "false"
  }

  capacity {
    provisioned_capacity {
      mcu_count    = 1
      worker_count = 1
    }
  }

  log_delivery {
    worker_log_delivery {
      cloudwatch_logs {
        enabled   = true
        log_group = aws_cloudwatch_log_group.msk_connect_logs.name
      }
    }
  }

  plugin {
    custom_plugin {
      arn      = aws_mskconnect_custom_plugin.msk_plugin.arn
      revision = aws_mskconnect_custom_plugin.msk_plugin.latest_revision
    }
  }

  tags = var.tags
}

resource "aws_mskconnect_custom_plugin" "msk_plugin" {
  name         = "${var.project_name}-custom-plugin-${var.environment}"
  content_type = "ZIP"
  location {
    s3 {
      bucket_arn = aws_s3_bucket.plugin_bucket.arn
      file_key   = "confluentinc-kafka-connect-s3-10.6.4.zip"
    }
  }
  tags = var.tags
}

resource "aws_cloudwatch_log_group" "msk_connect_logs" {
  name = "cloudlake-msk-connect-logs"
}