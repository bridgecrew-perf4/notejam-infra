# GitHub push to a branch triggers build and deploy to equivalent env on Cloud Run
resource "google_cloudbuild_trigger" "deploy" {
  provider    = google-beta
  project     = google_project_service.cloudbuild.project
  name        = "${var.project_name}-${terraform.workspace}-build-trigger"
  description = "Build ${var.project_name} app and deploy to ${terraform.workspace}"

  # NOTE: Cloud Build GitHub App needs to be added to app repo and authorized
  github {
    owner = var.cloudbuild_github_owner
    name  = var.cloudbuild_github_name
    push {
      branch = terraform.workspace
    }
  }

  build {
    # Build image based on flask app Dockerfile, tagged with commit hash
    step {
      name = "gcr.io/cloud-builders/docker"
      dir  = "flask"
      args = [
        "build",
        "-t",
        "gcr.io/$PROJECT_ID/${var.project_name}:$COMMIT_SHA",
        "."
      ]
    }
    # Push image to Container Registry with commit hash tag
    step {
      name = "gcr.io/cloud-builders/docker"
      dir  = "flask"
      args = [
        "push",
        "gcr.io/$PROJECT_ID/${var.project_name}:$COMMIT_SHA"
      ]
    }
    # Deploy the image to the Cloud Run service
    step {
      name       = "gcr.io/google.com/cloudsdktool/cloud-sdk"
      entrypoint = "gcloud"
      args = [
        "run",
        "deploy",
        local.cloudrun_service_name,
        "--image",
        "gcr.io/$PROJECT_ID/${var.project_name}:$COMMIT_SHA",
        "--region",
        var.region,
        "--platform",
        "managed"
      ]
    }
  }
}
