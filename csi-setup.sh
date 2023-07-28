#!/bin/bash

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
  read -p "Do you want to execute the AWS EBS Configuration commands? (y/n): " choice
  case "$choice" in
    y|Y ) return 0;;
    n|N ) return 1;;
    * ) echo "Invalid choice. Please enter 'y' or 'n'."; confirm_execution;;
  esac
}

# Get inputs from user
REGION_CODE=$(get_input "Enter AWS Region Code (e.g., us-west-2)")
CLUSTER_NAME=$(get_input "Enter Cluster Name")

# Fetch Root UID from AWS CLI command
ROOT_UID=$(aws sts get-caller-identity --query Account --output text)

echo " "
echo "REGION_CODE : " $REGION_CODE
echo "CLUSTER_NAME : " $CLUSTER_NAME
echo "ROOT_UID : " $ROOT_UID
echo " "

# Validate inputs (requires not null)
if [[ -z "$REGION_CODE" || -z "$CLUSTER_NAME" || -z "$ROOT_UID" ]]; then
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
  --name ebs-csi-controller-sa \
  --namespace kube-system \
  --cluster $CLUSTER_NAME \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --approve \
  --role-only \
  --role-name AmazonEKS_EBS_CSI_DriverRole_$CLUSTER_NAME &&

# Create Snapshot Components for EBS Storage Backup
echo "."
echo "Create Snapshot Components for EBS..."
# Create Customresourcedefinition 
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml &&
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml &&
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml &&

# Create Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/deploy/kubernetes/snapshot-controller/rbac-snapshot-controller.yaml &&
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/deploy/kubernetes/snapshot-controller/setup-snapshot-controller.yaml &&

echo "."
echo "Installing CSI Driver add-on to Cluster..."
eksctl create addon --region $REGION_CODE --name aws-ebs-csi-driver --cluster $CLUSTER_NAME --service-account-role-arn arn:aws:iam::$ROOT_UID:role/AmazonEKS_EBS_CSI_DriverRole_$CLUSTER_NAME --force &&

echo "."
echo "Register EBS CSI driver as StorageClass..."
kubectl apply -f https://raw.githubusercontent.com/msa-school/Lab-required-Materials/main/Ops/storage-class.yaml
kubectl patch storageclass gp2 -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'

echo "."
echo "."
echo "All AWS commands executed successfully."

