# AWS provider for the dev environment. default_tags applies the standard tag
# map from the tagging module to every taggable resource automatically
# (Req 9.1-9.4), so modules do not need to re-tag each resource.

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = module.tagging.tags
  }
}
