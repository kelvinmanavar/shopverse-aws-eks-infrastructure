# Pure tag-map and name-prefix helper. No AWS resources are created here; the
# module exposes a deterministic tag map and naming prefix that every other
# module in this project consumes. (Requirements 9.1-9.5.)

locals {
  # The four standard tags applied to every taggable resource.
  standard_tags = {
    "environment" = var.environment # Req 9.1
    "managed-by"  = "terraform"     # Req 9.2 (constant)
    "owner"       = var.owner       # Req 9.3
    "cost-center" = var.cost_center # Req 9.4
  }

  # extra_tags are merged FIRST so the standard tags always win on key
  # collision. This guarantees extra_tags can never override the four
  # standard keys (Req 9.1-9.4; Property 1).
  tags = merge(var.extra_tags, local.standard_tags)

  # Deterministic, environment-keyed naming prefix (Req 3.5, 9.5; Property 2).
  # Same inputs always produce the same output, and dev/prod differ by key.
  name_prefix_resolved = "${var.name_prefix}-${var.environment}"
}
