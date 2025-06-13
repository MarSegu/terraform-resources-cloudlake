resource "aws_s3_bucket" "raw_data_bucket" {
  bucket        = "${var.project_name}-raw-data-${var.environment}"
  force_destroy = true

  tags = var.tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = aws_s3_bucket.raw_data_bucket.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.msk_kms_key.arn
    }
  }
}

resource "aws_s3_bucket" "plugin_bucket" {
  bucket        = "${var.project_name}-msk-plugin-${var.environment}"
  force_destroy = true

  tags = var.tags
}