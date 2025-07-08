resource "aws_cloudwatch_log_group" "emr_log_group" {
  name = "/aws/emr/logs"
}

resource "aws_cloudwatch_log_stream" "emr_log_stream" {
  log_group_name = aws_cloudwatch_log_group.emr_log_group.name
  name           = "emr-log-stream"
}