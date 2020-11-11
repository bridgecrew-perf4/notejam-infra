provider "google" {
  region = var.region
}

resource "random_id" "id" {
  keepers = {
    project   = var.project_name
    workspace = terraform.workspace
  }
  byte_length = 4
  prefix      = "${var.project_name}-${terraform.workspace}-"
}

# Separate project for each workspace/environment
resource "google_project" "project" {
  name            = "${var.project_name}-${terraform.workspace}"
  project_id      = random_id.id.dec
  billing_account = var.billing_account
}

resource "google_project_service" "compute" {
  project = google_project.project.project_id
  service = "compute.googleapis.com"
}

resource "google_project_service" "iam" {
  project = google_project.project.project_id
  service = "iam.googleapis.com"
}

resource "google_project_service" "servicenetworking" {
  project = google_project.project.project_id
  service = "servicenetworking.googleapis.com"
}

resource "google_project_service" "sql-component" {
  project = google_project.project.project_id
  service = "sql-component.googleapis.com"
}

resource "google_project_service" "sqladmin" {
  project = google_project.project.project_id
  service = "sqladmin.googleapis.com"
}

resource "google_project_service" "run" {
  project = google_project.project.project_id
  service = "run.googleapis.com"
}

resource "google_project_service" "vpcaccess" {
  project = google_project.project.project_id
  service = "vpcaccess.googleapis.com"
}

resource "google_project_service" "cloudbuild" {
  project = google_project.project.project_id
  service = "cloudbuild.googleapis.com"
}

resource "google_project_service" "cloudscheduler" {
  project = google_project.project.project_id
  service = "cloudscheduler.googleapis.com"
}

resource "google_project_service" "storage-component" {
  project = google_project.project.project_id
  service = "storage-component.googleapis.com"
}

resource "google_project_service" "storage-api" {
  project = google_project.project.project_id
  service = "storage-api.googleapis.com"
}

resource "google_project_service" "logging" {
  project = google_project.project.project_id
  service = "logging.googleapis.com"
}
