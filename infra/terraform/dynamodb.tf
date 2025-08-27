resource "aws_dynamodb_table" "receipts" {
  name           = "receipts"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "pk"
  range_key      = "sk"

  attribute {
    name = "pk"
    type = "S"
  }
  attribute {
    name = "sk"
    type = "S"
  }

  tags = {
    Project = var.project_name
    Tenant  = var.tenant_id
  }
}
