data "google_compute_network" "selected" {
  name    = "default"
  project = var.project_id
}

resource "google_vpc_access_connector" "n8n" {
  name           = var.vpc_connector_name
  project        = var.project_id
  region         = var.region
  network        = data.google_compute_network.selected.name
  ip_cidr_range  = var.vpc_connector_cidr
  machine_type   = "e2-micro"
  min_instances  = 2
  max_instances  = 10
  min_throughput = 200
  max_throughput = 1000
}

