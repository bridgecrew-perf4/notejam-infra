locals {
  cloudrun_service_name = "${var.project_name}-${terraform.workspace}-cloudrun-service"
}

resource "google_cloud_run_service" "default" {
  name                       = local.cloudrun_service_name
  project                    = google_project_service.run.project
  location                   = var.region
  autogenerate_revision_name = true
  template {
    spec {
      service_account_name = google_service_account.cloudrun.email
      containers {
        # Cloud Build will overwrite this Cloud Run sample app and we ignore the changed image in lifecycle config
        image = "gcr.io/cloudrun/hello"
        resources {
          limits = {
            cpu    = "1000m"
            memory = "1Gi"
          }
        }
        ports {
          container_port = "8080"
        }
        # Notejam app expects always production env to use a MySQL database
        env {
          name  = "ENVIRONMENT"
          value = "production"
        }
        # TODO: Use Secret Manager and/or Berglas for database credentials
        env {
          name = "SQLALCHEMY_DATABASE_URI"
          value = format(
            "%s://%s:%s@%s/%s?charset=%s",
            "mysql+pymysql",
            google_sql_user.default.name,
            google_sql_user.default.password,
            google_sql_database_instance.master.private_ip_address,
            google_sql_database.default.name,
            "utf8mb4"
          )
        }
      }
    }
    # Use Serverless VPC Access
    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale"        = "1000",
        "run.googleapis.com/vpc-access-connector" = google_vpc_access_connector.default.name,
        "run.googleapis.com/vpc-access-egress"    = "private-ranges-only"
      }
    }
  }

  lifecycle {
    ignore_changes = [
      template[0].metadata[0].annotations,
      template[0].metadata[0].annotations["client.knative.dev/user-image"],
      template[0].metadata[0].annotations["run.googleapis.com/client-name"],
      template[0].metadata[0].annotations["run.googleapis.com/client-version"],
      template[0].spec[0].containers[0].image,
    ]
  }
  depends_on = [google_cloudbuild_trigger.deploy]
}

# Map domain DNS name to the Cloud Run service
resource "google_cloud_run_domain_mapping" "default" {
  location = var.region
  name     = trimsuffix(local.hostname, ".")
  project  = google_project_service.run.project
  metadata {
    namespace = google_project_service.run.project
    annotations = {
      "run.googleapis.com/launch-stage" : "BETA"
    }
  }
  spec {
    route_name = google_cloud_run_service.default.name
  }
  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
      metadata[0].annotations["serving.knative.dev/creator"],
      metadata[0].annotations["serving.knative.dev/lastModifier"]
    ]
  }
}
