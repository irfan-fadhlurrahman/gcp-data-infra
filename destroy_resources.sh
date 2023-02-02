#!/usr/bin/bash

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
