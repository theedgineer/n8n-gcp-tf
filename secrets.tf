# Clave de cifrado de credenciales de n8n
resource "random_password" "n8n_encryption_key" {
  length  = 64
  special = false
}

resource "random_password" "basic_auth_pass" {
  length  = 20
  special = true
}

# Secrets
resource "google_secret_manager_secret" "n8n_encryption_key" {
  secret_id = "N8N_ENCRYPTION_KEY"

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "n8n_encryption_key_v" {
  secret      = google_secret_manager_secret.n8n_encryption_key.id
  secret_data = random_password.n8n_encryption_key.result
}

resource "google_secret_manager_secret" "db_password" {
  secret_id = "N8N_DB_PASSWORD"

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "db_password_v" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db_password.result
}

resource "google_secret_manager_secret" "basic_auth_user" {
  secret_id = "N8N_BASIC_AUTH_USER"

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "basic_auth_user_v" {
  secret      = google_secret_manager_secret.basic_auth_user.id
  secret_data = "ed"
}

resource "google_secret_manager_secret" "basic_auth_pass" {
  secret_id = "N8N_BASIC_AUTH_PASSWORD"

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "basic_auth_pass_v" {
  secret      = google_secret_manager_secret.basic_auth_pass.id
  secret_data = random_password.basic_auth_pass.result
}

# Concede acceso a la SA de n8n para leer estos secretos
resource "google_secret_manager_secret_iam_member" "key_access" {
  for_each = {
    enc  = google_secret_manager_secret.n8n_encryption_key.id
    db   = google_secret_manager_secret.db_password.id
    user = google_secret_manager_secret.basic_auth_user.id
    pass = google_secret_manager_secret.basic_auth_pass.id
  }
  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.n8n.email}"
}
