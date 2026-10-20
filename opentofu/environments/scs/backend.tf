# First apply with a local backend override; migrate after creating and testing the bucket.
terraform {
  backend "s3" {}
}
