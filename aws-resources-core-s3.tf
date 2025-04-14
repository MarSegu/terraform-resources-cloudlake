resource "aws_s3_bucket" "raw_data_bucket" {
  bucket        = "${var.project_name}-raw-data-${var.environment}"
  force_destroy = true

  tags = var.tags
}

resource "aws_s3_bucket" "plugin_bucket" {
  bucket        = "${var.project_name}-msk-plugin-${var.environment}"
  force_destroy = true

  tags = var.tags
}