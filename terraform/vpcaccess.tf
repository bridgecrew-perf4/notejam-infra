variable "vpcaccess_ip_range" {
  default = "10.8.0.0/28"
}

variable "vpcaccess_max_throughput" {
  type = map
  default = {
    prod  = "1000"
    stage = "300"
  }
}

# Serverless VPC Access for Cloud Run to connect to Cloud SQL with private IP
resource "google_vpc_access_connector" "default" {
  project        = google_project_service.vpcaccess.project
  name           = "${var.project_name}-${terraform.workspace}-vpcaccess"
  network        = google_compute_network.default.name
  region         = var.region
  ip_cidr_range  = var.vpcaccess_ip_range
  max_throughput = lookup(var.vpcaccess_max_throughput, terraform.workspace, "stage")
}
