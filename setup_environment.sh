#!/bin/bash -x

if [ $# -ne 3 ]; then
    echo "Usage: $0 <PROJECT_ID> <GCP_USERNAME> <REGION>"
    exit 1
fi

# Get the inputs from command-line arguments
PROJECT_ID=$1
GCP_USERNAME=$2
REGION=$3

gcloud config set project $PROJECT_ID

# Set your project ID, username, and region
#PROJECT_ID="bootkon-test24mun-8301"  # Replace with your actual project ID
#GCP_USERNAME="medevstar8301"  # Replace with your actual GCP username
#REGION="us-central1"  # Replace with your preferred region

# Enable necessary APIs
gcloud services enable storage-component.googleapis.com notebooks.googleapis.com serviceusage.googleapis.com cloudresourcemanager.googleapis.com pubsub.googleapis.com compute.googleapis.com metastore.googleapis.com datacatalog.googleapis.com analyticshub.googleapis.com bigquery.googleapis.com dataplex.googleapis.com datalineage.googleapis.com dataform.googleapis.com dataproc.googleapis.com bigqueryconnection.googleapis.com aiplatform.googleapis.com

# Install Git and Git LFS
sudo apt-get update
sudo apt-get install git
sudo apt-get install git-lfs
git lfs install

# Clone the repository
git clone https://github.com/fhirschmann/bootkon-h2-2024.git
cd bootkon-h2-2024/
git lfs pull

# Verify checksums and remove checksum files
cd data-prediction
sha256sum -c checksums.sha256
rm -f checksums.sha256
cd ..
cd data-ingestion/csv/ulb_fraud_detection/
sha256sum -c checksums.sha256
rm -f checksums.sha256
cd ../..
cd parquet/ulb_fraud_detection/
sha256sum -c checksums.sha256
rm -f checksums.sha256
cd ../../..
cd metadata-mapping/
sha256sum -c checksums.sha256
rm -f checksums.sha256
cd ../

# Authenticate with GCP
gcloud auth login

# Grant IAM roles
chmod 700 prepare-environment/assign_roles.sh
./prepare-environment/assign_roles.sh $PROJECT_ID $GCP_USERNAME

# Create default VPC network and enable private access
SUBNET="default"
gcloud compute networks create $SUBNET --project=$PROJECT_ID --subnet-mode=auto --bgp-routing-mode="regional"
gcloud compute networks subnets update $SUBNET --region=$REGION --enable-private-ip-google-access
gcloud compute firewall-rules create "default-allow-all-internal" \
  --network="default" \
  --project=$PROJECT_ID \
  --direction=INGRESS \
  --priority=65534 \
  --source-ranges="10.128.0.0/9" \
  --allow=tcp:0-65535,udp:0-65535,icmp

# Create a Google Cloud Storage bucket
BUCKET_NAME="${PROJECT_ID}-bucket"
gsutil mb -l $REGION gs://$BUCKET_NAME

# Copy files to GCS
gsutil cp -R data-ingestion/csv/* gs://$BUCKET_NAME/data-ingestion/csv/
gsutil cp -R data-ingestion/jar/* gs://$BUCKET_NAME/data-ingestion/jar/
gsutil cp -R data-ingestion/src/* gs://$BUCKET_NAME/data-ingestion/src/
gsutil cp -R data-ingestion/parquet/* gs://$BUCKET_NAME/data-ingestion/parquet/
gsutil cp -R data-prediction/* gs://$BUCKET_NAME/data-prediction/
gsutil cp metadata-mapping/pca gs://$BUCKET_NAME/metadata-mapping/pca

# Direct upload the JAR file to GCS
gsutil cp gs://spark-lib/bigquery/spark-3.3-bigquery-0.37.0.jar gs://$BUCKET_NAME/jar/

echo "Environment setup complete!"
