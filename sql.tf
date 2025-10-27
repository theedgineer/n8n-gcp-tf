# Randoms
resource "random_password" "db_password" {
  length  = 24
  special = true
}

# Instancia Cloud SQL (Postgres 14)
resource "google_sql_database_instance" "pg" {
  name             = "n8n-sql"
  database_version = "POSTGRES_14"
  region           = var.region
  settings {
    tier              = var.db_tier
    availability_type = "ZONAL"
    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
    }
    ip_configuration {
      ipv4_enabled = true
      authorized_networks {
        name  = "all"
        value = "0.0.0.0/0"
      }
    }
    data_cache_config {
      data_cache_enabled = false
    }
  }

  depends_on = [google_project_service.services]
}

resource "google_sql_database" "db" {
  name     = "n8ndb"
  instance = google_sql_database_instance.pg.name
}

resource "google_sql_user" "user" {
  name     = "n8nuser"
  instance = google_sql_database_instance.pg.name
  password = random_password.db_password.result
}


