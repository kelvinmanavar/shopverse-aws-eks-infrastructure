output "tags" {
  description = "Merged standard tag map (environment, managed-by, owner, cost-center) plus any additive extra_tags. Fed to each module and to the provider default_tags block."
  value       = local.tags
}

output "name_prefix_resolved" {
  description = "Deterministic, environment-keyed name prefix, e.g. 'app-dev'. Each module appends its own logical resource suffix."
  value       = local.name_prefix_resolved
}
