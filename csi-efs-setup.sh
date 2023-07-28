#!/bin/bash

# Define the mapping list of AWS Region names and corresponding Image Repository names
declare -A region_repository_mapping

region_repository_mapping["af-south-1"]="877085696533.dkr.ecr.af-south-1.amazonaws.com"
region_repository_mapping["ap-east-1"]="800184023465.dkr.ecr.ap-east-1.amazonaws.com"
region_repository_mapping["ap-northeast-1"]="602401143452.dkr.ecr.ap-northeast-1.amazonaws.com"
region_repository_mapping["ap-northeast-2"]="602401143452.dkr.ecr.ap-northeast-2.amazonaws.com"
region_repository_mapping["ap-northeast-3"]="602401143452.dkr.ecr.ap-northeast-3.amazonaws.com"
region_repository_mapping["ap-south-1"]="602401143452.dkr.ecr.ap-south-1.amazonaws.com"
region_repository_mapping["ap-south-2"]="900889452093.dkr.ecr.ap-south-2.amazonaws.com"
region_repository_mapping["ap-southeast-1"]="602401143452.dkr.ecr.ap-southeast-1.amazonaws.com"
region_repository_mapping["ap-southeast-2"]="602401143452.dkr.ecr.ap-southeast-2.amazonaws.com"
region_repository_mapping["ap-southeast-3"]="296578399912.dkr.ecr.ap-southeast-3.amazonaws.com"
region_repository_mapping["ap-southeast-4"]="491585149902.dkr.ecr.ap-southeast-4.amazonaws.com"
region_repository_mapping["ca-central-1"]="602401143452.dkr.ecr.ca-central-1.amazonaws.com"
region_repository_mapping["cn-north-1"]="918309763551.dkr.ecr.cn-north-1.amazonaws.com.cn"
region_repository_mapping["cn-northwest-1"]="961992271922.dkr.ecr.cn-northwest-1.amazonaws.com.cn"
region_repository_mapping["eu-central-1"]="602401143452.dkr.ecr.eu-central-1.amazonaws.com"
region_repository_mapping["eu-central-2"]="900612956339.dkr.ecr.eu-central-2.amazonaws.com"
region_repository_mapping["eu-north-1"]="602401143452.dkr.ecr.eu-north-1.amazonaws.com"
region_repository_mapping["eu-south-1"]="590381155156.dkr.ecr.eu-south-1.amazonaws.com"
region_repository_mapping["eu-south-2"]="455263428931.dkr.ecr.eu-south-2.amazonaws.com"
region_repository_mapping["eu-west-1"]="602401143452.dkr.ecr.eu-west-1.amazonaws.com"
region_repository_mapping["eu-west-2"]="602401143452.dkr.ecr.eu-west-2.amazonaws.com"
region_repository_mapping["eu-west-3"]="602401143452.dkr.ecr.eu-west-3.amazonaws.com"
region_repository_mapping["me-south-1"]="558608220178.dkr.ecr.me-south-1.amazonaws.com"
region_repository_mapping["me-central-1"]="759879836304.dkr.ecr.me-central-1.amazonaws.com"
region_repository_mapping["sa-east-1"]="602401143452.dkr.ecr.sa-east-1.amazonaws.com"
region_repository_mapping["us-east-1"]="602401143452.dkr.ecr.us-east-1.amazonaws.com"
region_repository_mapping["us-east-2"]="602401143452.dkr.ecr.us-east-2.amazonaws.com"
region_repository_mapping["us-gov-east-1"]="151742754352.dkr.ecr.us-gov-east-1.amazonaws.com"
region_repository_mapping["us-gov-west-1"]="013241004608.dkr.ecr.us-gov-west-1.amazonaws.com"
region_repository_mapping["us-west-1"]="602401143452.dkr.ecr.us-west-1.amazonaws.com"
region_repository_mapping["us-west-2"]="602401143452.dkr.ecr.us-west-2.amazonaws.com"
# Add more region-repository pairs as needed


# Function to prompt user for input with validation
function get_input() {
  local var
  while [[ -z "$var" ]]; do
    read -p "$1: " var
  done
  echo "$var"
}

# Function to ask for confirmation before executing commands
function confirm_execution() {
  read -p "Do you want to execute the AWS EFS Configuration commands? (y/n): " choice
  case "$choice" in
    y|Y ) return 0;;
    n|N ) return 1;;
    * ) echo "Invalid choice. Please enter 'y' or 'n'."; confirm_execution;;
  esac
}


# Get inputs from user
REGION_CODE=$(get_input "Enter AWS Region Code (e.g., us-west-2)")
CLUSTER_NAME=$(get_input "Enter Cluster Name")
FILE_SYSTEM_ID=$(get_input "Enter File System ID")

# Check if the input region exists in the mapping list
if [ -n "${region_repository_mapping[$REGION_CODE]}" ]; then
    echo " "
else
    echo " "
    echo "Error: Image Repository not found for region $REGION_CODE"
    exit 1  # Exit the script with a non-zero status code to indicate an error
fi

# Fetch Root UID from AWS CLI command
ROOT_UID=$(aws sts get-caller-identity --query Account --output text)

echo " "
echo "REGION_CODE : " $REGION_CODE
echo "CLUSTER_NAME : " $CLUSTER_NAME
echo "ROOT_UID : " $ROOT_UID
echo "FILE_SYSTEM_ID : " $FILE_SYSTEM_ID
echo "Image Repository for $REGION_CODE : " ${region_repository_mapping[$REGION_CODE]}
echo " "

# Validate inputs (requires not null)
if [[ -z "$REGION_CODE" || -z "$CLUSTER_NAME" || -z "$ROOT_UID" || -z "$FILE_SYSTEM_ID" ]]; then
  echo " " 
  echo "Error: All parameters must have non-null values."
  exit 1
fi

# Confirm before executing AWS commands
confirm_execution || exit 0

# Create IAM ServiceAccount and Attach AmazonEBSCSIDriver Policy to Cluster
echo "."
echo "Creating IAM ServiceAccount..."
eksctl create iamserviceaccount \
  --override-existing-serviceaccounts \
  --region $REGION_CODE \
  --name efs-csi-controller-sa \
  --namespace kube-system \
  --cluster $CLUSTER_NAME \
  --attach-policy-arn arn:aws:iam::$ROOT_UID:policy/EFSCSIControllerIAMPolicy \
  --approve &&

# Create aws-efs-csi-driver and upgrade with Helm 
echo "."
echo "Create aws-efs-csi-driver and upgrade with Helm..."
helm repo add aws-efs-csi-driver https://kubernetes-sigs.github.io/aws-efs-csi-driver &&
helm repo update &&
helm upgrade -i aws-efs-csi-driver aws-efs-csi-driver/aws-efs-csi-driver \
  --namespace kube-system \
  --set image.repository=${region_repository_mapping[$REGION_CODE]}/eks/aws-efs-csi-driver \
  --set controller.serviceAccount.create=false \
  --set controller.serviceAccount.name=efs-csi-controller-sa &&

echo "."
echo "Register EFS CSI driver as StorageClass..."
curl -o efs-sc.yaml https://raw.githubusercontent.com/msa-school/Lab-required-Materials/main/Ops/efs-storage-class.yaml &&
sed -i "s/FILE_SYSTEM_ID/$FILE_SYSTEM_ID/g" efs-sc.yaml &&
kubectl apply -f efs-sc.yaml

echo "."
echo "."
echo "All AWS commands executed successfully."


