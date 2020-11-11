terraform {
  backend "gcs" {
    bucket = "lupudev-tfstate"
    prefix = "notejam"
  }
}
