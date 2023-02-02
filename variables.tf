# General
variable "project_id" {
  description = "Your GCP Project ID"
}
variable "credentials" {
  description = "Your GCP credentials path location"
}
variable "region" {
  description = "Region for GCP resources. Choose as per your location: https://cloud.google.com/about/locations"
}
variable "zone" {
  description = "Zone for GCP resources. Choose as per your location: https://cloud.google.com/about/locations"
}

# VM Disk
variable "disk_image" {
  description = "Ubuntu 22.04 LTS, check on gcloud compute images list"
  default = "ubuntu-os-cloud/ubuntu-2204-jammy-v20230114"
  type = string
}
variable "disk_type" {
  description = "SSD type disk storage"
  default = "pd-balanced"
  type = string
}
variable "disk_size_gb" {
  description = "Total GB of disk size"
  default = 40
}

# VM Instance
variable "cpu_name" {
  description = "Type of CPU"
  default = "c2d-standard-2"
  type = string
}

# Cloud Storage and BigQuery
locals {
  data_lake_bucket = "dtc_data_lake"
}
variable "storage_class" {
  description = "Storage class type for your bucket. Check official docs for more info."
  default = "STANDARD"
}
variable "BQ_DATASET" {
  description = "BigQuery Dataset that raw data (from GCS) will be written to"
  type = string
  default = "trips_data_all"
}

