# Make Cloud Run service available for public
data "google_iam_policy" "noauth" {
  binding {
    role    = "roles/run.invoker"
    members = ["allUsers"]
  }
}

resource "google_cloud_run_service_iam_policy" "noauth" {
  location    = google_cloud_run_service.default.location
  project     = google_cloud_run_service.default.project
  service     = google_cloud_run_service.default.name
  policy_data = data.google_iam_policy.noauth.policy_data
}

# Service account for running Cloud Run
resource "google_service_account" "cloudrun" {
  project      = google_project_service.iam.project
  account_id   = "${var.project_name}-${terraform.workspace}-cloudrun"
  display_name = "${var.project_name} ${terraform.workspace} Cloud Run"
}

# Allow Cloud Run to access Cloud SQL
resource "google_project_iam_member" "cloudrun_cloudsql" {
  project = google_project_service.iam.project
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.cloudrun.email}"
}

# Allow Cloud Build to admin Cloud Run
resource "google_project_iam_member" "cloudsql_cloudrun" {
  project = google_project_service.iam.project
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_project.project.number}@cloudbuild.gserviceaccount.com"
}

# Bind Cloud Build to Cloud Run service account
data "google_iam_policy" "cloudbuild" {
  binding {
    role = "roles/iam.serviceAccountUser"
    members = [
      "serviceAccount:${google_project.project.number}@cloudbuild.gserviceaccount.com",
    ]
  }
  depends_on = [google_project_service.iam]
}

resource "google_service_account_iam_policy" "cloudbuild" {
  service_account_id = google_service_account.cloudrun.name
  policy_data        = data.google_iam_policy.cloudbuild.policy_data
}

# Allow Cloud SQL exports to backup Cloud Storage bucket
resource "google_storage_bucket_iam_member" "sql_backup" {
  bucket = google_storage_bucket.backup.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_sql_database_instance.master.service_account_email_address}"
}

# Service account for Cloud Scheduler to export Cloud SQL databases
resource "google_service_account" "sqlexport" {
  project      = google_project_service.iam.project
  account_id   = "${var.project_name}-${terraform.workspace}-sqlexport"
  display_name = "Service Account for Cloud SQL Exports"
}

resource "google_project_iam_custom_role" "sqlexport" {
  project     = google_project_service.iam.project
  role_id     = "sqlexport"
  title       = "Cloud SQL export"
  description = "Cloud Storage Export Custom Role"
  permissions = [
    "cloudsql.instances.export",
  ]
}

resource "google_project_iam_binding" "sqlexport" {
  project = google_project_service.iam.project
  role    = "projects/${google_project.project.project_id}/roles/${google_project_iam_custom_role.sqlexport.role_id}"
  members = [
    "serviceAccount:${google_service_account.sqlexport.email}",
  ]
}

# Permit developers to see logs, builds and sql on Cloud Console
resource "google_project_iam_member" "logging-viewer" {
  project = google_project_service.iam.project
  role    = "roles/logging.viewer"
  member  = "group:${var.developer_google_group}"
}

resource "google_project_iam_member" "cloudbuild-builder" {
  project = google_project_service.iam.project
  role    = "roles/cloudbuild.builds.builder"
  member  = "group:${var.developer_google_group}"
}

resource "google_project_iam_member" "cloudsql-viewer" {
  project = google_project_service.iam.project
  role    = "roles/cloudsql.viewer"
  member  = "group:${var.developer_google_group}"
}
