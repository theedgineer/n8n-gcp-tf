variable "project_id" {
  description = "ID del proyecto GCP (ya con billing habilitado)"
  type        = string
}

variable "region" {
  description = "Región de despliegue (ej. us-central1)"
  type        = string
  default     = "us-central1"
}

variable "service_name" {
  description = "Nombre del servicio Cloud Run"
  type        = string
  default     = "n8n"
}

variable "n8n_image" {
  description = "Imagen de n8n"
  type        = string
  default     = "docker.io/n8nio/n8n:latest"
}

variable "db_tier" {
  description = "Tamaño de instancia Cloud SQL"
  type        = string
  default     = "db-f1-micro"
}

variable "timezone" {
  description = "TZ de n8n"
  type        = string
  default     = "America/Mexico_City"
}

variable "min_instances" {
  description = "Mínimo de instancias Cloud Run (0 para ahorro)"
  type        = number
  default     = 1
}

variable "max_instances" {
  description = "Máximo de instancias Cloud Run"
  type        = number
  default     = 1
}

