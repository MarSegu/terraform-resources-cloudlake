resource "aws_emr_cluster" "data_emr_cluster" {
  name          = "${var.project_name}-data-emr-cluster-${var.environment}"
  release_label = "emr-7.3.0"
  applications  = ["Hadoop", "Hive", "Spark", "Livy", "JupyterEnterpriseGateway"]

  log_uri = "s3://${aws_s3_bucket.data_emr_logs.bucket}/log-emr/"

  master_instance_group {
    instance_type  = "m5.xlarge"
    instance_count = 1
  }

  core_instance_group {
    instance_type  = "m5.xlarge"
    instance_count = 1
  }

  # EC2 Configuration (for security groups, IAM role, and SSH key)
  ec2_attributes {
    emr_managed_master_security_group = aws_security_group.emr_sg.id
    emr_managed_slave_security_group  = aws_security_group.emr_sg.id
    instance_profile                  = aws_iam_instance_profile.ec2_instance_profile.arn
    #key_name         = "bastionec2"  # Specify your key pair
    subnet_id = aws_subnet.public_data_az1.id
  }

  # Configure YARN and Spark
  configurations = jsonencode([
    {
      classification = "yarn-site"
      properties = {
        "yarn.log-aggregation-enable" = "true"
        "yarn.nodemanager.log-dirs"   = "/var/log/hadoop-yarn/container-logs"
      }
    },
    {
      classification = "spark-env"
      properties = {
        "PYSPARK_PYTHON" = "/usr/bin/python3"
      }
    }
  ])

  # Service role and termination protection
  service_role           = aws_iam_role.emr_role.arn
  termination_protection = false

  visible_to_all_users = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-data-emr-cluster-${var.environment}"
    }
  )

}

#extra Instance for tasks
resource "aws_emr_instance_group" "task" {
  cluster_id     = aws_emr_cluster.data_emr_cluster.id
  instance_count = 1
  instance_type  = "m5.xlarge"
  name           = "${var.project_name}-tasks-instance-${var.environment}"
}

resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-ec2-emr-role-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_policy_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceforEC2Role"
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "${var.project_name}-ec2-instance-profile-${var.environment}"
  role = aws_iam_role.ec2_role.name
}

resource "aws_iam_role" "emr_role" {
  name = "${var.project_name}-emr-role-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "elasticmapreduce.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "emr_policy_attachment" {
  role       = aws_iam_role.emr_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonElasticMapReduceFullAccess"
}

resource "aws_iam_role_policy_attachment" "ec2_redshift_data_full" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonRedshiftDataFullAccess"
}

resource "aws_iam_role_policy_attachment" "ec2_redshift_full" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonRedshiftFullAccess"
}

resource "aws_iam_role_policy_attachment" "ec2_secrets_read_write" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

resource "aws_iam_policy" "ec2_custom_s3_policy" {
  name        = "${var.project_name}-custom-s3-policy-${var.environment}"
  description = "Custom S3 access policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:AbortMultipartUpload",
          "s3:CreateBucket",
          "s3:DeleteObject",
          "s3:GetBucketVersioning",
          "s3:GetObject",
          "s3:GetObjectTagging",
          "s3:GetObjectVersion",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:ListBucketVersions",
          "s3:ListMultipartUploadParts",
          "s3:PutBucketVersioning",
          "s3:PutObject",
          "s3:PutObjectTagging"
        ],
        Resource = ["arn:aws:s3:::*"]
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "ec2_attach_custom_s3" {
  name       = "attach-${aws_iam_policy.ec2_custom_s3_policy.name}"
  roles      = [aws_iam_role.ec2_role.name]
  policy_arn = aws_iam_policy.ec2_custom_s3_policy.arn
}

#security groups
resource "aws_security_group" "emr_sg" {
  name        = "${var.project_name}-emr-sg-${var.environment}"
  description = "EMR cluster security group"
  vpc_id      = aws_vpc.cloudlake_data_vpc.id
}

resource "aws_security_group_rule" "ingress_rule" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.emr_sg.id
}

resource "aws_security_group_rule" "emr_sg_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.emr_sg.id
}
