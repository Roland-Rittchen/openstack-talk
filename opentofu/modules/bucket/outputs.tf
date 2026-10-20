output "bucket_name" { value = aws_s3_bucket.this.id }
output "bucket_endpoint" { value = var.endpoint }
output "region" { value = var.region }
