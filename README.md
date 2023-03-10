# Setting up of Data Infrastructure on Google Cloud Platform

To automate the process of setting up a data infrastructure that consists of a Compute Engine, a Cloud Storage bucket, and a table in BigQuery.

## Prerequisite
* GCP Account
* Installed Google Cloud SDK

## Main tools
* Terraform
* Google Cloud SDK

## Terraform Configuration
### Terraform Variables

The following below are variables used to run a data infrastructure on GCP.
* Project ID
* Service Account File
* Region
* Zone
* Disk Image: default: **ubuntu-os-cloud/ubuntu-2204-jammy-v20230114**
* Disk Type: default: **pd-balanced**
* Disk Size (in GB): default: **40**
* Instance Image: default: **c2d-standard-2** (Compute-Optimized 2-Core 8 GB RAM)
* Bucket Name: default: **dtc_data_lake**
* Storage Class: default: **STANDARD**
* BigQuery Table Name: default: **trips_data_all**

### VPC Network
```terraform
resource "google_compute_network" "vpc_network" {
  name = "terraform-network"
}
```
### Compute Disk for VM
```terraform
resource "google_compute_disk" "vm-disk-1" {
    name = "vm-disk-1"
    image = var.disk_image
    zone = var.zone
    type = var.disk_type
    size = var.disk_size_gb
}
```
### Compute Instance
```terraform
resource "google_compute_instance" "vm-instance-1" {
    name         = "vm-instance-1"
    machine_type = var.cpu_name
    tags         = ["daily-vm-instance"]
    zone         = var.zone
    
    boot_disk {
      source = google_compute_disk.vm-disk-1.self_link
      }

    network_interface {
      network = google_compute_network.vpc_network.name
      access_config {

      }
    }
}
```
### Firewall for SSH Access Rule
```terraform
resource "google_compute_firewall" "ssh-rule" {
  name = "allow-ssh"
  network = google_compute_network.vpc_network.name
  allow {
    protocol = "tcp"
    ports = ["22"]
  }
  target_tags = ["daily-vm-instance"]
  source_ranges = ["0.0.0.0/0"]
}
```
### Data Lake Bucket
```terraform
resource "google_storage_bucket" "data-lake-bucket" {
  name          = "${local.data_lake_bucket}_${var.project_id}" # Concatenating DL bucket & Project name for unique naming
  location      = var.region

  # Optional, but recommended settings:
  storage_class = var.storage_class
  uniform_bucket_level_access = true

  versioning {
    enabled     = true
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 30  // days
    }
  }

  force_destroy = true
}
```

### BigQuery Data Warehouse 
```terraform
resource "google_bigquery_dataset" "dataset" {
  dataset_id = var.BQ_DATASET
  project    = var.project_id
  location   = var.region
}
```

## Setup

### Install Terraform
```bash
# setup/setup_gcp.sh

echo 'Create a folder for storing downloaded file'
sleep 2
mkdir ~/bin && cd ~/bin

echo "Download and Install Terraform"
sleep 2
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

echo "Append current path to .bashrc (export PATH=HOME/bin:PATH)"
sleep 10
nano ~/.bashrc

echo "Apply changes"
sleep 2
source ~/.bashrc

echo "Verify Installation"
terraform -help
```

### Configure .env variables
For reference, copy env to .env then define as per own machine.
```bash
# .env

# Project
USER=your-username
SSH_IDENTIFIER_NAME=your-unique-name
GCP_BILLING_ACC_ID=your-billing-acc-id
GCP_PROJECT_ID=your-project-id

# General
GCP_REGION=region
GCP_ZONE=zone
SERVICE_ACCOUNT_NAME=vm-name
GCP_CREDENTIALS="path/to/vm-name.json"
```

### Setup GCP Project
Run the following shell command below.
```bash
# setup/setup_gcp.sh

echo "Export all variables to shell session"
sleep 2
source "./.env"

echo "Creating project "${GCP_PROJECT_ID}""
gcloud projects create ${GCP_PROJECT_ID}

echo "Setting the project as default project"
sleep 3
gcloud config set project ${GCP_PROJECT_ID}

echo "Linking the billing account with the project"
sleep 3
gcloud beta billing projects link ${GCP_PROJECT_ID} --billing-account=${GCP_BILLING_ACC_ID}

echo "Enable GCP APIs"
sleep 2
gcloud services enable iam.googleapis.com
gcloud services enable iamcredentials.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable bigqueryconnection.googleapis.com

echo "Create Service Account"
sleep 2
gcloud iam service-accounts create ${SERVICE_ACCOUNT_NAME} \
--display-name="Data Infrastructure for Data Engineering Projects"

echo "Grant the Service Account the Necessary Permissions"
sleep 2
# Compute Engine
gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
--member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
--role="roles/compute.admin"

# BigQuery
gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
--member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
--role="roles/bigquery.admin"

# Viewer
gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
--member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
--role="roles/viewer"

# Storage
gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
--member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
--role="roles/storage.admin"

# Storage Transfer
gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
--member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
--role="roles/storagetransfer.admin"

echo "Create a JSON key for this Service Account"
sleep 2
gcloud iam service-accounts keys create ${SERVICE_ACCOUNT_NAME}.json \
--iam-account ${SERVICE_ACCOUNT_NAME}@${GCP_PROJECT_ID}.iam.gserviceaccount.com

echo "Create a secret folder for credentials"
sleep 2
mkdir -p ~/.ssh/credentials

echo "Move a JSON key to secret folder"
sleep 2
mv ${SERVICE_ACCOUNT_NAME}.json ~/.ssh/credentials
export VM_GOOGLE_CREDENTIALS="~/.ssh/credentials/${SERVICE_ACCOUNT_NAME}.json"

echo "Create a SSH key"
sleep 3
ssh-keygen -t rsa -f ~/.ssh/${GCP_PROJECT_ID} -C ${USER} -b 2048

echo "Add username to SSH public key with format (USERNAME:KEY) and add to metadata"
cat ~/.ssh/${GCP_PROJECT_ID}.pub > key_with_user
var="${USER}:$(<key_with_user)"
gcloud compute project-info add-metadata \
--metadata-from-file=ssh-keys=key_with_user
rm key_with_user

echo "Find VM External IP before build connection via SSH https://cloud.google.com/compute/docs/instances/view-ip-address"
gcloud compute instances list
```

### Run all resources
To run all resources automatically, export Terraform Variables to shell session.
```bash
# run_resources.sh

echo "Exporting Terraform variables to Shell session."
sleep 3
source "./.env"
export TF_VAR_project_id="${GCP_PROJECT_ID}" 
export TF_VAR_credentials="${GCP_CREDENTIALS}" 
export TF_VAR_region="${GCP_REGION}" 
export TF_VAR_zone="${GCP_ZONE}"

echo "Run Selected Resources"
sleep 2
terraform init
terraform validate
terraform plan
terraform apply -auto-approve
```

### Destroy all resources
If all resource not used again, destroy with these commands automatically.
```bash
# destroy_resources.sh

echo "Exporting Terraform variables to Shell session."
sleep 3
source "./.env"
export TF_VAR_project_id="${GCP_PROJECT_ID}" 
export TF_VAR_credentials="${GCP_CREDENTIALS}" 
export TF_VAR_region="${GCP_REGION}" 
export TF_VAR_zone="${GCP_ZONE}"

echo "Destroy Resources"
sleep 2
terraform destroy -auto-approve
```
