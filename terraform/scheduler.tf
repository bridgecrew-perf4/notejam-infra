# Cloud Scheduler needs application in one of the regions where supported
resource "google_app_engine_application" "sql_backup_scheduler" {
  project     = google_project_service.cloudscheduler.project
  location_id = "europe-west3" # Frankfurt, Germany
}

# Daily Cloud SQL export to Google Cloud Storage bucket using Cloud Scheduler
data "template_file" "sql_exportcontext" {
  template = <<EOF
{
  "exportContext": {
    "kind": "sql#exportContext",
    "fileType": "SQL",
    "uri": "gs://${google_storage_bucket.backup.name}/${google_sql_database.default.name}.sql.gz",
    "databases": ["${google_sql_database.default.name}"]
  }
}
EOF
}

resource "google_cloud_scheduler_job" "sql_backup" {
  project          = google_project_service.cloudscheduler.project
  region           = "europe-west3"
  name             = "${var.project_name}-${terraform.workspace}-sql-backup-scheduler"
  schedule         = "0 3 * * *"
  description      = "Export Cloud SQL database to backup GCS bucket daily"
  time_zone        = "Europe/Helsinki"
  attempt_deadline = "30s"
  http_target {
    uri         = "https://sqladmin.googleapis.com/sql/v1beta4/projects/${google_project_service.sql-component.project}/instances/${google_sql_database_instance.master.name}/export"
    http_method = "POST"
    body        = base64encode(data.template_file.sql_exportcontext.rendered)
    oauth_token {
      service_account_email = google_service_account.sqlexport.email
    }
  }
  depends_on = [
    google_app_engine_application.sql_backup_scheduler
  ]
}
