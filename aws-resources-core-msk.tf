resource "aws_msk_cluster" "cloudlake_msk" {
  cluster_name           = "${var.project_name}-msk-${var.environment}"
  kafka_version          = "3.2.0"
  number_of_broker_nodes = 3

  broker_node_group_info {
    instance_type = "kafka.t3.small"
    client_subnets = [
      aws_subnet.private_core_az1.id,
      aws_subnet.private_core_az2.id,
      aws_subnet.private_core_az3.id
    ]
    security_groups = [aws_security_group.msk_sg.id]
    storage_info {
      ebs_storage_info {
        volume_size = 10
      }
    }
  }

  encryption_info {
    encryption_at_rest_kms_key_arn = aws_kms_key.msk_kms_key.arn

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

resource "aws_kms_key" "msk_kms_key" {
  description                        = "kms_kafka"
  key_usage                          = "ENCRYPT_DECRYPT"
  customer_master_key_spec           = "SYMMETRIC_DEFAULT"
  is_enabled                         = true
  enable_key_rotation                = false
  multi_region                       = false
  bypass_policy_lockout_safety_check = false

  tags = var.tags
}

data "aws_caller_identity" "current" {}

resource "aws_kms_key_policy" "kafka_kms_policy" {
  key_id = aws_kms_key.msk_kms_key.key_id

  policy = jsonencode({
    Version = "2012-10-17",
    Id      = "kms-kafka-policy",
    Statement = [
      {
        Sid    = "AllowKafkaServiceUse",
        Effect = "Allow",
        Principal = {
          Service = "kafka.amazonaws.com"
        },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = "*"
      },
      {
        Sid    = "AllowSSOAdminAccess",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::767398097168:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdministratorAccess_c11af16de08388a9"
        },
        Action   = "kms:*",
        Resource = "*"
      },
      {
        Sid    = "AllowRootAccountAccess",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*",
        Resource = "*"
      }
    ]
  })
}

resource "aws_security_group" "msk_sg" {
  name        = "${var.project_name}-msk-sg-${var.environment}"
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

  ingress {
    description     = "Allow Kafka plaintext traffic from EC2 client"
    from_port       = 9092
    to_port         = 9092
    protocol        = "tcp"
    security_groups = [aws_security_group.kafka_client_sg.id]
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
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ],
        Resource = [
          aws_s3_bucket.plugin_bucket.arn,
          "${aws_s3_bucket.plugin_bucket.arn}/*",
          aws_s3_bucket.raw_data_bucket.arn,
          "${aws_s3_bucket.raw_data_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ],
        Resource = aws_kms_key.msk_kms_key.arn
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "kafka-cluster:Connect",
          "kafka-cluster:DescribeCluster",
          "kafka-cluster:DescribeConfiguration",
          "kafka-cluster:GetBootstrapBrokers",
          "kafka-cluster:DescribeClusterVpcConnection"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_mskconnect_connector" "cloudlake_connector" {
  name                       = "${var.project_name}-msk-s3-connector-${var.environment}"
  kafkaconnect_version       = "2.7.1"
  service_execution_role_arn = aws_iam_role.msk_connect_execution_role.arn

  kafka_cluster {
    apache_kafka_cluster {
      bootstrap_servers = aws_msk_cluster.cloudlake_msk.bootstrap_brokers_tls
      vpc {
        security_groups = [aws_security_group.msk_sg.id]
        subnets = [
          aws_subnet.private_core_az1.id,
          aws_subnet.private_core_az2.id
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
    "topics"                         = "s3-raw-topic"
    "s3.bucket.name"                 = aws_s3_bucket.raw_data_bucket.bucket
    "s3.region"                      = var.aws_region
    "flush.size"                     = "1"
    "storage.class"                  = "io.confluent.connect.s3.storage.S3Storage"
    "format.class"                   = "io.confluent.connect.s3.format.json.JsonFormat"
    "partitioner.class"              = "io.confluent.connect.storage.partitioner.DefaultPartitioner"
    "value.converter"                = "org.apache.kafka.connect.json.JsonConverter"
    "value.converter.schemas.enable" = "false"
    "behavior.on.null.values"   = "ignore"
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
  name = "${var.project_name}-msk-connect-logs"
}

# MSK Management
resource "aws_security_group" "kafka_client_sg" {
  name        = "kafka-client-sg-${var.environment}"
  description = "SG for Kafka CLI client"
  vpc_id      = aws_vpc.cloudlake_core.id

  # Allow inbound HTTPS traffic from the VPC
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.cloudlake_core.cidr_block]
  }

  # Allow SSM session traffic
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.cloudlake_core.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "aws_instance" "kafka_client" {
  ami                    = "ami-0c2b8ca1dad447f8a"
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.private_core_az1.id
  vpc_security_group_ids = [aws_security_group.kafka_client_sg.id]
  key_name               = var.ec2_msk_key_name

  iam_instance_profile = aws_iam_instance_profile.ec2_ssm_profile.name

  user_data = <<-EOF
#!/bin/bash

# Update and install necessary tools
yum update -y
amazon-linux-extras install java-openjdk11 -y
yum install wget -y
yum install -y tar

# Download and install Kafka
wget https://downloads.apache.org/kafka/3.7.2/kafka_2.13-3.7.2.tgz -P /tmp
tar -xvzf /tmp/kafka_2.13-3.7.2.tgz -C /opt
ln -s /opt/kafka_2.13-3.7.2 /opt/kafka

# Create client.properties for MSK connectivity
mkdir -p /opt/kafka/config
cat > /opt/kafka/config/client.properties << 'EOL'
security.protocol=SSL
ssl.endpoint.identification.algorithm=
ssl.truststore.location=/tmp/kafka.client.truststore.jks
ssl.truststore.password=changeit
EOL

# Create script to set up MSK truststore
mkdir -p /opt/kafka/bin
cat > /opt/kafka/bin/setup-msk-truststore.sh << 'EOL'
#!/bin/bash
mkdir -p /tmp/kafka-certs
wget -O /tmp/kafka-certs/AmazonRootCA1.pem https://www.amazontrust.com/repository/AmazonRootCA1.pem
wget -O /tmp/kafka-certs/AmazonRootCA2.pem https://www.amazontrust.com/repository/AmazonRootCA2.pem
wget -O /tmp/kafka-certs/AmazonRootCA3.pem https://www.amazontrust.com/repository/AmazonRootCA3.pem
wget -O /tmp/kafka-certs/AmazonRootCA4.pem https://www.amazontrust.com/repository/AmazonRootCA4.pem
rm -f /tmp/kafka.client.truststore.jks
keytool -keystore /tmp/kafka.client.truststore.jks -alias AmazonRootCA1 -import -file /tmp/kafka-certs/AmazonRootCA1.pem -storepass changeit -noprompt
keytool -keystore /tmp/kafka.client.truststore.jks -alias AmazonRootCA2 -import -file /tmp/kafka-certs/AmazonRootCA2.pem -storepass changeit -noprompt
keytool -keystore /tmp/kafka.client.truststore.jks -alias AmazonRootCA3 -import -file /tmp/kafka-certs/AmazonRootCA3.pem -storepass changeit -noprompt
keytool -keystore /tmp/kafka.client.truststore.jks -alias AmazonRootCA4 -import -file /tmp/kafka-certs/AmazonRootCA4.pem -storepass changeit -noprompt
EOL

chmod +x /opt/kafka/bin/setup-msk-truststore.sh
/opt/kafka/bin/setup-msk-truststore.sh

# Create Kafka environment configuration with static JAVA_HOME
export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))

cat << EOL > /etc/profile.d/kafka-env.sh
#!/bin/bash
export JAVA_HOME=$JAVA_HOME
export PATH=\$PATH:\$JAVA_HOME/bin:/opt/kafka/bin
export KAFKA_HEAP_OPTS="-Xmx2G -Xms1G"
export KAFKA_JVM_PERFORMANCE_OPTS="-XX:MetaspaceSize=96m -XX:+UseG1GC -XX:MaxGCPauseMillis=20 -XX:InitiatingHeapOccupancyPercent=35 -XX:G1HeapRegionSize=16M -XX:MinMetaspaceFreeRatio=50 -XX:MaxMetaspaceFreeRatio=80"
export KAFKA_OPTS="-Xmx1G -Xms512M"
EOL

chmod +x /etc/profile.d/kafka-env.sh
EOF


  tags = merge(
    var.tags,
    {
      Name = "kafka-cli-${var.environment}"
    }
  )
}

resource "aws_iam_role" "ec2_ssm_role" {
  name = "ec2-ssm-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_ssm_policy" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "ec2_kafka_access" {
  name = "ec2-ssm-msk-access-${var.environment}"
  role = aws_iam_role.ec2_ssm_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "kafka:GetBootstrapBrokers"
        ],
        Resource = "arn:aws:kafka:us-east-1:008966042112:cluster/cloudlake-msk-dev/df3dcf9f-f284-4126-bfb9-456e45044ed1-1"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "ec2-ssm-profile-${var.environment}"
  role = aws_iam_role.ec2_ssm_role.name
}

# SSM Endpoints
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.cloudlake_core.id
  service_name        = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_core_az1.id]
  security_group_ids  = [aws_security_group.vpce_sg.id]
  private_dns_enabled = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-ssm-endpoint-${var.environment}"
    }
  )
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = aws_vpc.cloudlake_core.id
  service_name        = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_core_az1.id]
  security_group_ids  = [aws_security_group.vpce_sg.id]
  private_dns_enabled = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-ssmmessages-endpoint-${var.environment}"
    }
  )
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = aws_vpc.cloudlake_core.id
  service_name        = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_core_az1.id]
  security_group_ids  = [aws_security_group.vpce_sg.id]
  private_dns_enabled = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-ec2messages-endpoint-${var.environment}"
    }
  )
}

# S3 Gateway endpoint
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.cloudlake_core.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private_core_rt.id]

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-s3-endpoint-${var.environment}"
    }
  )
}

