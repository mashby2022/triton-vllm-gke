# GKE Autopilot
export PROJECT_ID=class-426015
export HF_TOKEN= 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
export REGION=us-central1
export ZONE_1=${REGION}-a # You may want to change the zone letter based on the region you selected above
export ZONE_2=${REGION}-b # You may want to change the zone letter based on the region you selected above
export CLUSTER_NAME=triton-inference
export NAMESPACE=triton
gcloud config set project "$PROJECT_ID"
gcloud config set compute/region "$REGION"
gcloud config set compute/zone "$ZONE_1"

gcloud container clusters create $CLUSTER_NAME --location ${REGION} \
  --workload-pool ${PROJECT_ID}.svc.id.goog \
  --enable-image-streaming --enable-shielded-nodes \
  --shielded-secure-boot --shielded-integrity-monitoring \
  --enable-ip-alias \
  --node-locations=$REGION-b \
  --workload-pool=${PROJECT_ID}.svc.id.goog \
  --addons GcsFuseCsiDriver   \
  --no-enable-master-authorized-networks \
  --machine-type n2d-standard-4 \
  --cluster-version 1.28 \
  --num-nodes 1 --min-nodes 1 --max-nodes 3 \
  --ephemeral-storage-local-ssd=count=2 \
  --scopes="gke-default,storage-rw"

gcloud container node-pools create $CLUSTER_NAME-pool --cluster \
$CLUSTER_NAME --accelerator type=nvidia-l4,count=1,gpu-driver-version=latest   --machine-type g2-standard-8 \
--ephemeral-storage-local-ssd=count=1   --enable-autoscaling --enable-image-streaming   --num-nodes=0 --min-nodes=0 --max-nodes=3 \
--shielded-secure-boot   --shielded-integrity-monitoring --node-version=1.28 --node-locations $ZONE_1,$ZONE_2 --region $REGION --spot
TRITON_SA=triton-server
gcloud iam service-accounts create $TRITON_SA --display-name "Triton Server Service Account"
for role in monitoring.metricWriter stackdriver.resourceMetadata.writer; do
  gcloud projects add-iam-policy-binding $PROJECT_ID --member=serviceAccount:${TRITON_SA}@${PROJECT_ID}.iam.gserviceaccount.com --role=roles/${role}
done
kubectl create ns triton
kubectl create serviceaccount triton --namespace triton
gcloud iam service-accounts add-iam-policy-binding ${TRITON_SA}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role roles/iam.workloadIdentityUser \
    --member "serviceAccount:${PROJECT_ID}.svc.id.goog[triton/triton]"

kubectl annotate serviceaccount triton \
    --namespace triton \
    iam.gke.io/gcp-service-account=${TRITON_SA}@${PROJECT_ID}.iam.gserviceaccount.com

kubectl create secret generic huggingface --from-literal="HF_TOKEN=$HF_TOKEN" -n $NAMESPACE

kubectl apply -f vllm-podmonitoring.yaml -n $NAMESPACE
