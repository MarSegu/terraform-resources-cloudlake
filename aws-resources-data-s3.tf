resource "aws_s3_bucket" "processed_data" {
  bucket = "${var.project_name}-processed-data-${var.environment}"

  tags = var.tags
}

resource "aws_s3_bucket" "curated_data" {
  bucket = "${var.project_name}-curated-data-${var.environment}"

  tags = var.tags
}

#EMR logs
resource "aws_s3_bucket" "data_emr_logs" {
  bucket = "${var.project_name}-data-log-emr-${var.environment}"
  tags   = var.tags
}

resource "aws_s3_object" "data_log_config" {
  bucket  = aws_s3_bucket.data_emr_logs.bucket
  key     = "log-config.txt"
  content = "log configuration content"
}
