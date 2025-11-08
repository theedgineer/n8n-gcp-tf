# Obtiene el connectionName de la instancia (project:region:instance)
data "google_sql_database_instance" "pg" {
  name = google_sql_database_instance.pg.name
}

# Cloud Run v1 (estable y simple para anotaciones del conector Cloud SQL)
resource "google_cloud_run_service" "n8n" {
  name     = var.service_name
  location = var.region

  template {
    spec {
      service_account_name  = google_service_account.n8n.email
      container_concurrency = 50
      timeout_seconds       = 600

      containers {
        image = var.n8n_image

        ports {
          container_port = 5678
        }

        # Env Vars (las sensibles vienen de Secret Manager)
        env {
          name  = "N8N_PORT"
          value = "5678"
        }
        env {
          name  = "N8N_HOST"
          value = "0.0.0.0"
        }
        env {
          name  = "N8N_PROTOCOL"
          value = "https"
        }
        env {
          name  = "GENERIC_TIMEZONE"
          value = var.timezone
        }
        env {
          name  = "N8N_PERSONALIZATION_ENABLED"
          value = "false"
        }
        env {
          name  = "N8N_SECURE_COOKIE"
          value = "true"
        }
        env {
          name  = "N8N_BASIC_AUTH_ACTIVE"
          value = "true"
        }
        env {
          name  = "EXECUTIONS_MODE"
          value = "regular"
        }
        env {
          name  = "N8N_USER_MANAGEMENT_DISABLED"
          value = var.n8n_user_management_disabled ? "true" : "false"
        }
        env {
          name  = "WEBHOOK_URL"
          value = var.webhook_url
        }

        # DB config
        env {
          name  = "DB_TYPE"
          value = "postgresdb"
        }
        env {
          name  = "DB_POSTGRESDB_DATABASE"
          value = google_sql_database.db.name
        }
        env {
          name  = "DB_POSTGRESDB_HOST"
          value = "/cloudsql/${var.project_id}:${var.region}:${google_sql_database_instance.pg.name}"
        }
        env {
          name  = "DB_POSTGRESDB_PORT"
          value = "5432"
        }
        env {
          name  = "DB_POSTGRESDB_USER"
          value = google_sql_user.user.name
        }

        env {
          name  = "DB_POSTGRESDB_INIT_MAX_RETRIES"
          value = "15"
        }

        # Secrets
        env {
          name  = "N8N_ENCRYPTION_KEY"
          value = ""
          value_from {
            secret_key_ref {
              name = google_secret_manager_secret.n8n_encryption_key.secret_id
              key  = "latest"
            }
          }
        }
        env {
          name  = "DB_POSTGRESDB_PASSWORD"
          value = ""
          value_from {
            secret_key_ref {
              name = google_secret_manager_secret.db_password.secret_id
              key  = "latest"
            }
          }
        }
        env {
          name  = "N8N_BASIC_AUTH_USER"
          value = ""
          value_from {
            secret_key_ref {
              name = google_secret_manager_secret.basic_auth_user.secret_id
              key  = "latest"
            }
          }
        }
        env {
          name  = "N8N_BASIC_AUTH_PASSWORD"
          value = ""
          value_from {
            secret_key_ref {
              name = google_secret_manager_secret.basic_auth_pass.secret_id
              key  = "latest"
            }
          }
        }

        resources {
          limits = {
            memory = "2Gi"
            cpu    = "1000m"
          }
        }

        startup_probe {
          period_seconds    = 240
          failure_threshold = 1
          timeout_seconds   = 240
          tcp_socket {
            port = 5678
          }
        }
      }
    }

    metadata {
      annotations = {
        # Conectividad
        "run.googleapis.com/cloudsql-instances"   = "${var.project_id}:${var.region}:${google_sql_database_instance.pg.name}"
        "run.googleapis.com/startup-cpu-boost"    = "true"
        "run.googleapis.com/vpc-access-connector" = google_vpc_access_connector.n8n.name
        "run.googleapis.com/vpc-access-egress"    = "private-ranges-only"
        # Escalado
        "autoscaling.knative.dev/minScale" = var.min_instances
        "autoscaling.knative.dev/maxScale" = var.max_instances
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  autogenerate_revision_name = true

  depends_on = [
    google_project_service.services,
    google_secret_manager_secret_iam_member.key_access,
    google_sql_user.user,
    google_vpc_access_connector.n8n
  ]
}

# Permitir acceso público (invoker anónimo) — protegido por Basic Auth de n8n
resource "google_cloud_run_service_iam_member" "public_invoker" {
  location = google_cloud_run_service.n8n.location
  project  = var.project_id
  service  = google_cloud_run_service.n8n.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
