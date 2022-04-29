output "resource_group_name" {
  value = data.kubectl_file_documents.apply.content
}