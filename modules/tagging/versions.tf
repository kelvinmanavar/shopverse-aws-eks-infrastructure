terraform {
  # Bounded on both ends (Req 1.4, 1.7). This module is pure HCL (locals only)
  # and declares no provider, so only the core version is constrained here.
  required_version = ">= 1.16.0, < 2.0.0"
}
