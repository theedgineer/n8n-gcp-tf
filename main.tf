# Habilita APIs necesarias
resource "google_project_service" "services" {
  for_each = toset([
    "run.googleapis.com",
    "sqladmin.googleapis.com",
    "secretmanager.googleapis.com",
    "artifactregistry.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "compute.googleapis.com"
  ])
  project = var.project_id
  service = each.key
}

# Service Account dedicada para n8n (principio de mínimo privilegio)
resource "google_service_account" "n8n" {
  account_id   = "n8n-sa"
  display_name = "n8n Cloud Run Service Account"
}

# Permisos mínimos:
# - Cloud SQL Client (para usar el conector)
# - Secret Manager Secret Accessor (leer secretos)
# - Logs Writer (emitir logs)
resource "google_project_iam_member" "sa_cloudsql" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.n8n.email}"
}

resource "google_project_iam_member" "sa_secrets" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.n8n.email}"
}

resource "google_project_iam_member" "sa_logs" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.n8n.email}"
}


