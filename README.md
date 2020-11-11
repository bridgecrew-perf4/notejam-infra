# Serverless GitOps for Notejam app on Google Cloud Platform with Terraform

This example will provide serverless cloud native infrastructure on Google Cloud Platform and GitOps style continuous deployment for a sample web application using Terraform configuration management. Buzzword compliance achieved so let's move on:

## Requirements

We have the following requirements for the application:

- **Delivery**: Large team of developers needs to be able to deliver new versions of the app continuously without downtime. We will use Google Cloud Build CI/CD pipeline integrated to GitHub to test and deploy the app automatically to Cloud Run.
- **Environments**: Self-contained but functionally identical production, staging, testing and development environments are needed for the application development lifecycle. We will use Terraform Workspaces for that.
- **Scalability**: Usage of the app varies greatly and it needs to be scaling up and down automatically. We will use Google Cloud Run serverless container platform to accomplish that.
- **Continuity**: Application should be available in the case of a datacenter malfunction. We will use Cloud Run and HA for Cloud SQL to host the app in multiple availability zones in a region.
- **Durability**: Application data needs be recoverable for up to three years in case of a disaster of user error. We will use Google Cloud SQL as a database and store daily backups on Google Cloud Storage.
- **Visibility**: Logs and metrics need to be available for compliance and QA. We will use Google Cloud Logging and Cloud IAM to accomplish that.
- **Portability**: Migration to another region of the cloud provider needs to be possible in case of a disaster. We will not demonstrate that ability in this example but Google Cloud SQL replication and Terraform configuration for a warm failover environment would enable that.

## Notejam sample web application

> Notejam is a unified sample web application (more than just "Hello World") implemented using different server-side frameworks.

We will use the python/flask version of the [Notejam](https://github.com/komarserjio/notejam) sample web application. A fork of the app at https://github.com/lupupitkanen/notejam is needed for the following changes:

- Adds `Dockerfile` for the flask app
- Adds `PyMySQL` database library for using Cloud SQL for MySQL on production instead of SQLite
- Changes app to listen on all interfaces (`0.0.0.0`) instead of `localhost`
- Changes app to listen on port `8080` instead of `5000`
- Changes external resource URLs to `//` instead of insecure `http://` URLs

Potential changes relevant to actual production but not for this sample app example:

- uWSGI or Gunicorn would be used for a production python app
- E-mail sending would need to be fixed as we don't have SMTP on `localhost` at Cloud Run
- Security for database credentials

## GitHub account and app repo

- Create a GitHub account or use your existing one: https://github.com/join
- Fork this forked Notejam app repo to your own account: https://github.com/lupupitkanen/notejam/fork

## Google Cloud Platform prequisites

- [Create a Google Cloud Platform account](https://console.cloud.google.com/freetrial)
- [Create a Google Cloud Billing account](https://cloud.google.com/billing/docs/how-to/manage-billing-account)
- [Install the Cloud Build GitHub app](https://cloud.google.com/cloud-build/docs/automating-builds/run-builds-on-github) (but don't connect any repositories just yet)
- [Create a Google Group which includes your developers](https://groups.google.com/my-groups)
- [Install Google Cloud SDK](https://cloud.google.com/sdk/docs/install)

## Preparation

Not everything can be managed with Terraform so you will first need to:

- Bootstrap your configuration with variables specific to your environment
- Create a base Google Cloud Platform project
- Create a Google Cloud Storage bucket to store your Terraform states remotely
- Register your own domain name using Google Cloud Domains
- Create a Google Cloud DNS zone to use for your Notejam app deployment

### Clone this repository to your workstation

```
mkdir ~/projects
cd ~/projects
git clone git@github.com:lupupitkanen/notejam-infra.git
cd notejam-infra
```

### Your environment

Please create a `.env` file based using the provided `.env.example` as a guide and source the file.

```
cp .env.example .env
nano .env # or use your preferred editor
source .env
```

### Create configuration and authenticate to GCP
```
gcloud config configurations create $PROJECT_NAME
gcloud auth login $ACCOUNT --update-adc
```

### Create a project for domain and Terraform state and link to billing acccount
```
gcloud projects create $PROJECT_ID --name=$PROJECT_NAME --set-as-default
gcloud beta billing projects link $PROJECT_ID --billing-account=$BILLING_ACCOUNT
```

### Enable services
```
gcloud services enable \
  dns.googleapis.com \
  domains.googleapis.com \
  storage.googleapis.com \
  storage-component.googleapis.com
  ```

### Create a versioned GCS bucket for Terraform remote state
```
gsutil mb -b on -l $GCP_REGION gs://$PROJECT_NAME-tfstate
gsutil versioning set on gs://$PROJECT_NAME-tfstate
```

### Create a DNS zone
```
gcloud dns managed-zones create ${ZONE} --dns-name="$DOMAIN." --description="$DOMAIN DNS zone"
gcloud dns managed-zones update ${ZONE} --dnssec-state on
```

### Register a domain
```
cat <<EOT > contacts.yaml
allContacts:
  email: '$DOMAIN_EMAIL'
  phoneNumber: '$DOMAIN_PHONE'
  postalAddress:
    regionCode: '$DOMAIN_REGION'
    postalCode: '$DOMAIN_POSTAL'
    locality: '$DOMAIN_LOCALITY'
    addressLines: ['$DOMAIN_ADDRESS']
    recipients: ['$DOMAIN_RECIPIENT']
EOT
gcloud alpha domains registrations get-register-parameters $DOMAIN
gcloud alpha domains registrations register $DOMAIN \
--contact-data-from-file=contacts.yaml \
--contact-privacy=private-contact-data \
--cloud-dns-zone=${ZONE} \
--notices=hsts-preloaded \
--yearly-price="12.00 USD"
gcloud alpha domains registrations describe $DOMAIN
```

## Terraform

You will now setup the infrastructure for your Notejam app on Google Cloud Platform using [Terraform](https://www.terraform.io/) configuration management.

### Install Terraform and tfswitch

- [Install Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli) (version `0.13.5`)
- Or [install `tfswitch` utility to manage Terraform versions](https://tfswitch.warrensbox.com/Install/)
- Change to terraform dir and switch the terraform version if necessary
```
cd terraform
tfswitch
```

### Create backend config

```
cat <<EOT > backend.tf
terraform {
  backend "gcs" {
    bucket  = "$PROJECT_NAME-tfstate"
    prefix  = "notejam"
  }
}
EOT
```

This is because variables are not allowed in the backend config.

### Create tfvars file from previously set environment
```
cat <<EOT > terraform.tfvars
billing_account = "$BILLING_ACCOUNT"
project_name = "notejam"
project_zone = "$ZONE"
domain_project_id = "$PROJECT_ID"
region = "$GCP_REGION"
cloudbuild_github_owner = "$GITHUB_OWNER"
cloudbuild_github_name = "$GITHUB_NAME"
developer_google_group = "$DEVELOPER_GOOGLE_GROUP"
EOT
```

### Initialize Terraform
```
terraform init
```

### Create Terraform workspaces and apply config for each

Each Terraform [workspace](https://www.terraform.io/docs/state/workspaces.html) is equivalent to app environment *and* project in GCP.

We will create two workspaces:
- `prod` for your production environment where the actual users are using the app
- `stage` for your staging environment where the QA team can verify new versions of the app before going live on production

```
terraform workspace new stage
terraform workspace select stage
terraform plan
terraform apply
terraform workspace new prod
terraform workspace select prod
terraform plan
terraform apply
```

### ClickOps: GitHub and Google Cloud Build integration

Terraform apply did not finish without errors? That's expected:

Terraform config needs to be applied several times per environment because [there is no method to add repository connection in the Cloud Build API](https://issuetracker.google.com/issues/142550612) so some ClickOps is needed:

- Between the `terraform apply` runs, you need to connect your GitHub Notejam app repository to both of your GCP projects in the [Google Cloud Console](https://console.cloud.google.com/cloud-build/triggers/connect) manually.

### Triggering builds and final Terraform apply

Our Terraform config does not trigger build and deployment of the Notejam app itself but deploys the Cloud Run Hello sample application initially instead. Let's trigger the build:

- Commit a change in your Notejam app repository and push it first to `stage` and then `prod` branch. This should trigger a build in the Cloud Build which progress and history you can follow on Cloud Console.

Please note that DNS propagation and SSL certificate issuance to Cloud Run can take some time, but after that you should be able to use the Notejam app under your own domain, for example:

- Staging: https://notejam-stage.example.com/
- Production: https://notejam.example.com/

## Finish line

:dart: Congratulations! You are now able to provide GitOps workflow and serverless cloud native app deployments using Terraform.
