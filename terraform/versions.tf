# Lock Terraform and provider versions for predictability
terraform {
  required_version = "= 0.13.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "= 3.47.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "= 3.47.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "= 3.0.0"
    }
  }
}
