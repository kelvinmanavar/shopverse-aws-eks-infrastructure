terraform {
  # Distinct state key from dev keeps the two environments fully isolated. Server-side encryption on.
  backend "s3" {
    bucket       = "shopverse-tfstate-16102026"
    key          = "dev/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}
