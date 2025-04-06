resource "aws_msk_cluster" "cloudlake_msk" {
  cluster_name           = "cloudlake-msk"
  kafka_version          = "3.4.0"
  number_of_broker_nodes = 2

  broker_node_group_info {
    instance_type   = "kafka.m5.large"
    client_subnets  = [
      aws_subnet.private_az1.id,
      aws_subnet.private_az2.id,
    ]
    security_groups = [aws_security_group.msk_sg.id]
    storage_info {
      ebs_storage_info {
        volume_size = 100
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
  name        = "cloudlake-msk-sg"
  description = "Security group for MSK cluster"
  vpc_id      = aws_vpc.cloudlake_core.id

  # Allow inbound traffic from within the VPC (e.g., MSK Connect, EC2, etc.)
  ingress {
    description      = "Allow Kafka traffic over TLS from VPC"
    from_port        = 9094
    to_port          = 9094
    protocol         = "tcp"
    cidr_blocks      = [aws_vpc.cloudlake_core.cidr_block]
  }

  # Allow MSK to talk to itself (brokers to brokers, etc.)
  ingress {
    description      = "Internal broker-to-broker communication"
    from_port        = 0
    to_port          = 65535
    protocol         = "tcp"
    self             = true
  }

  # Egress: allow all outbound traffic (default behavior)
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "msk_cloudwatch" {
  name = "msk_broker_logs"
}