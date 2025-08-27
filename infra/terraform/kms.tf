resource "aws_kms_key" "anchor" {
  description             = "Anchor key for ${var.project_name} tenant ${var.tenant_id}"
  customer_master_key_spec = "ECC_SECG_P256K1"
  key_usage               = "SIGN_VERIFY"
}

resource "aws_kms_alias" "anchor_alias" {
  name          = "alias/bsv/tenant/${var.tenant_id}/anchor"
  target_key_id = aws_kms_key.anchor.key_id
}

resource "aws_kms_key" "issue" {
  description             = "Issue key for ${var.project_name} tenant ${var.tenant_id}"
  customer_master_key_spec = "ECC_SECG_P256K1"
  key_usage               = "SIGN_VERIFY"
}

resource "aws_kms_alias" "issue_alias" {
  name          = "alias/bsv/tenant/${var.tenant_id}/issue"
  target_key_id = aws_kms_key.issue.key_id
}
