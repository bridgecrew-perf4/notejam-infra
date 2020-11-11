variable "subnetwork_map" {
  type = map
  default = {
    prod  = "10.10.11.0/24"
    stage = "10.10.12.0/24"
  }
}

variable "service_network_map" {
  type = map
  default = {
    prod  = "10.20.0.0"
    stage = "10.30.0.0"
  }
}

resource "google_compute_network" "default" {
  name                    = "${var.project_name}-${terraform.workspace}-network"
  auto_create_subnetworks = false
  project                 = google_project_service.compute.project
}

resource "google_compute_subnetwork" "default" {
  name          = "${var.project_name}-${terraform.workspace}-subnetwork"
  ip_cidr_range = lookup(var.subnetwork_map, terraform.workspace, "prod")
  network       = google_compute_network.default.self_link
  project       = google_project_service.compute.project
}

# Cloud SQL Private IP
resource "google_compute_global_address" "private_ip_address" {
  name          = "${var.project_name}-${terraform.workspace}-private-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = lookup(var.service_network_map, terraform.workspace, "prod")
  prefix_length = 16
  network       = google_compute_network.default.self_link
  project       = google_project_service.servicenetworking.project
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.default.self_link
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}
