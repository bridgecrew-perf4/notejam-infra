variable "sql_tier" {
  type = map
  default = {
    prod  = "db-g1-small"
    stage = "db-f1-micro"
  }
}

# Google Cloud SQL MySQL instance with HA in production environment
resource "google_sql_database_instance" "master" {
  name             = "${var.project_name}-${terraform.workspace}-master"
  project          = google_project_service.sql-component.project
  database_version = "MYSQL_5_7"

  settings {
    tier              = lookup(var.sql_tier, terraform.workspace, "stage")
    disk_type         = "PD_SSD"
    disk_autoresize   = true
    availability_type = terraform.workspace == "prod" ? "REGIONAL" : "ZONAL"

    ip_configuration {
      require_ssl     = false
      ipv4_enabled    = false
      private_network = google_compute_network.default.self_link
    }

    backup_configuration {
      binary_log_enabled = true
      enabled            = true
      start_time         = "01:00"
    }

    maintenance_window {
      day          = "6"
      hour         = "23"
      update_track = "stable"
    }
  }

  depends_on = [google_service_networking_connection.private_vpc_connection]
}

# Create database and user with random password
resource "google_sql_database" "default" {
  project  = google_project_service.sql-component.project
  name     = var.project_name
  instance = google_sql_database_instance.master.name
}

resource "random_string" "sql_password" {
  keepers = {
    project = google_project_service.sql-component.project
    region  = var.region
  }
  special = false
  length  = 16
}

resource "google_sql_user" "default" {
  project  = google_project_service.sql-component.project
  instance = google_sql_database_instance.master.name
  name     = var.project_name
  password = random_string.sql_password.result
}
