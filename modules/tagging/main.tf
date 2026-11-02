locals {
  standard_tags = {
    "environment" = var.environment 
    "managed-by"  = "terraform"     
    "owner"       = var.owner       
    "cost-center" = var.cost_center 
  }

  # extra_tags are merged FIRST so the standard tags always win on key
  # collision. This guarantees extra_tags can never override the four
  # standard keys.
  tags = merge(var.extra_tags, local.standard_tags)

  name_prefix_resolved = "${var.name_prefix}-${var.environment}"
}
