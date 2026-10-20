# Feature probe before enabling versioning, lifecycle, encryption or object lock:
# support varies by endpoint. Phase 2 relies on private ACLs and tested conditional
# writes for backend locking, with independent local state checkpoints for recovery.
resource "aws_s3_bucket" "this" {
  bucket        = var.name
  force_destroy = var.force_destroy
  lifecycle {
    prevent_destroy = true
  }
}
resource "aws_s3_bucket_acl" "private" {
  bucket = aws_s3_bucket.this.id
  acl    = "private"
}

# Manage only after probing version recovery AND locking together.
# Suspension may be needed to retain historical versions without breaking locks.
resource "aws_s3_bucket_versioning" "this" {
  count  = var.versioning_status == "Disabled" ? 0 : 1
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = var.versioning_status
  }
}
