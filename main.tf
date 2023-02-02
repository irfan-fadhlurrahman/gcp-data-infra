terraform {
    required_providers {
        google = {
            source = "hashicorp/google"
        }
    }
}

provider "google" {
  project = var.project_id
  region  = var.region
  credentials = file(var.credentials)
}

# Create a VPC network
resource "google_compute_network" "vpc_network" {
  name = "terraform-network"
}

# Define a Disk Information for VM
resource "google_compute_disk" "vm-disk-1" {
    name = "vm-disk-1"
    image = var.disk_image
    zone = var.zone
    type = var.disk_type
    size = var.disk_size_gb
}

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

# Configure SSH access of VM
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

# Data Lake Bucket
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket
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

# DWH
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/bigquery_dataset
resource "google_bigquery_dataset" "dataset" {
  dataset_id = var.BQ_DATASET
  project    = var.project_id
  location   = var.region
}