output "run_url" {
  value       = google_cloud_run_service.n8n.status[0].url
  description = "URL pública de n8n (con Basic Auth)"
}

output "db_instance" {
  value       = google_sql_database_instance.pg.name
  description = "Nombre de la instancia Cloud SQL"
}

output "basic_auth_user" {
  value       = "ed"
  description = "Usuario Basic Auth"
}

output "basic_auth_password_secret" {
  value       = google_secret_manager_secret.basic_auth_pass.id
  description = "ID del secreto que contiene la contraseña Basic Auth"
}





