# API Keys DynamoDB Table
resource "aws_dynamodb_table" "api_keys" {
  name           = "api-keys"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "apiKey"

  attribute {
    name = "apiKey"
    type = "S"
  }

  attribute {
    name = "tenant"
    type = "S"
  }

  global_secondary_index {
    name            = "tenant-index"
    hash_key        = "tenant"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Project = var.project_name
    Tenant  = var.tenant_id
  }
}
