# Google Cloud Storage bucket for Cloud SQL exports
resource "google_storage_bucket" "backup" {
  project       = google_project_service.storage-component.project
  name          = "${var.project_name}-${terraform.workspace}-backup"
  storage_class = "REGIONAL"
  location      = var.region
  force_destroy = false
  # Enable versioning to use always the same file name in Cloud Scheduler export
  versioning {
    enabled = "true"
  }
  # Move old exports to coldline storage tier after one week
  lifecycle_rule {
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
    condition {
      age        = "7"
      with_state = "ARCHIVED"
    }
  }
  # Delete old exports after 3 years
  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age        = "1095"
      with_state = "ARCHIVED"
    }
  }
  # Write protect for 3 years if required by customer
  # retention_policy {
  #   is_locked        = true
  #   retention_period = "94608000"
  # }
}
