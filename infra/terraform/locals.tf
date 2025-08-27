locals {
  name_prefix = "${var.project_name}-${var.tenant_id}"
  bucket_name = "${lower(replace(var.project_name, "_", "-"))}-${lower(var.tenant_id)}-artifacts-${formatdate("YYYY-MM-DD", timestamp())}"
}
