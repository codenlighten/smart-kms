resource "aws_s3_bucket" "artifacts" {
  count = var.create_artifacts_bucket ? 1 : 0
  bucket = local.bucket_name
  force_destroy = false
  tags = {
    Project = var.project_name
    Tenant  = var.tenant_id
  }
}
