resource "aws_lakeformation_resource" "s3_raw_bucket" {
  arn      = aws_s3_bucket.raw_data_bucket.arn
  role_arn = aws_iam_role.lakeformation_admin.arn
}

resource "aws_iam_role" "lakeformation_admin" {
  name = "LakeFormationAdminRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Principal = {
        Service = "lakeformation.amazonaws.com"
      },
      Effect = "Allow",
      Sid    = ""
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lakeformation_policy" {
  role       = aws_iam_role.lakeformation_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AWSLakeFormationDataAdmin"
}

resource "aws_lakeformation_permissions" "grant_emr" {
  principal = aws_iam_role.emr_role.arn

  permissions = ["DATA_LOCATION_ACCESS"]

  data_location {
    arn = aws_lakeformation_resource.s3_raw_bucket.arn
  }
  depends_on = [aws_iam_role.emr_role, aws_lakeformation_resource.s3_raw_bucket]
}

resource "aws_lakeformation_permissions" "grant_glue_catalog" {
  principal = aws_iam_role.emr_role.arn

  permissions = ["DESCRIBE"]

  database {
    name = aws_glue_catalog_database.raw_data.name
  }

  depends_on = [aws_iam_role.emr_role, aws_lakeformation_resource.s3_raw_bucket]
}

resource "aws_glue_catalog_database" "raw_data" {
  name = "raw_data_db"
}