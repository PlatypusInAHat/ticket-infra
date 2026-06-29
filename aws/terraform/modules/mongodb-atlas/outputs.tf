output "cluster_id" {
  description = "MongoDB cluster ID"
  value       = mongodbatlas_cluster.main.cluster_id
}

output "cluster_connection_string" {
  description = "MongoDB cluster connection string"
  value       = mongodbatlas_cluster.main.connection_strings[0].standard
  sensitive   = true
}

output "cluster_srv_connection_string" {
  description = "MongoDB cluster SRV connection string"
  value       = mongodbatlas_cluster.main.connection_strings[0].standard_srv
  sensitive   = true
}

output "database_username" {
  description = "MongoDB database username"
  value       = mongodbatlas_database_user.app.username
}

output "project_id" {
  description = "MongoDB project ID"
  value       = mongodbatlas_project.main.id
}
