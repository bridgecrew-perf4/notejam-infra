# Lock Terraform and provider versions for predictability
terraform {
  required_version = "= 0.14.4"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "= 3.52.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "= 3.52.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "= 3.0.1"
    }
    template = {
      source  = "hashicorp/template"
      version = "2.2.0"
    }
  }
}
