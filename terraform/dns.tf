# NOTE: Domain DNS zone resides in different project
data "google_dns_managed_zone" "default" {
  project = var.domain_project_id
  name    = var.project_zone
}

# DNS name for the app for example myapp.example.com for prod environment and myapp-stage.example.com for stage environment
locals {
  hostname = format(
    "%s.%s",
    terraform.workspace == "prod" ? var.project_name : format("%s-%s", var.project_name, terraform.workspace),
    data.google_dns_managed_zone.default.dns_name
  )
}

# Get DNS record value from Cloud Run domain mapping
resource "google_dns_record_set" "default" {
  project      = var.domain_project_id
  name         = local.hostname
  type         = google_cloud_run_domain_mapping.default.status[0].resource_records[0].type
  ttl          = 300
  managed_zone = data.google_dns_managed_zone.default.name
  rrdatas      = [google_cloud_run_domain_mapping.default.status[0].resource_records[0].rrdata]
}

# Output the URL of the application
output "application_url" {
  value = format("https://%s/", trimsuffix(local.hostname, "."))
}
