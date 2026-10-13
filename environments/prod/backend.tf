terraform {
  # Remote state in S3 with native S3 locking (use_lockfile) — no DynamoDB
  # table (Req 2.1, 2.2). Distinct state key from dev keeps the two
  # environments fully isolated (Req 2.3, 3.1). Server-side encryption on
  # (Req 2.4).
  #
  # NOTE: bucket is intentionally a placeholder. The state bucket is created by
  # the bootstrap/ root module; set the real name here (or pass via
  # `-backend-config`) once bootstrap has run.
  backend "s3" {
    bucket       = "REPLACE_WITH_BOOTSTRAP_STATE_BUCKET"
    key          = "prod/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}
