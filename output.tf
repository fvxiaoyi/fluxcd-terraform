/*output "apply" {
  value = local.apply
}*/

output "sync" {
  value = data.kubectl_file_documents.sync.content
}