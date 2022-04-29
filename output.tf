output "apply" {
  value = data.flux_sync.main.secret
}

output "sync" {
  value = data.flux_sync.main.namespace
}