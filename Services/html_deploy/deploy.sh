#!/bin/bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

PROJECT="gds-apac"
REGION="asia-northeast3"
SERVICE="mosaic"
IMAGE="gcr.io/${PROJECT}/${SERVICE}:latest"

echo "Building and pushing image via Cloud Build…"
gcloud builds submit \
  --tag "$IMAGE" \
  --project "$PROJECT" \
  .

echo "Deploying to Cloud Run…"
gcloud run deploy "$SERVICE" \
  --image "$IMAGE" \
  --region "$REGION" \
  --project "$PROJECT" \
  --platform managed \
  --allow-unauthenticated \
  --memory 512Mi \
  --cpu 1 \
  --min-instances 0 \
  --max-instances 3 \
  --set-env-vars APP_BASE_URL=https://mosaic-326198683934.asia-northeast3.run.app \
  --set-secrets \
    GOOGLE_CLIENT_ID=mosaic-google-client-id:latest,\
GOOGLE_CLIENT_SECRET=mosaic-google-client-secret:latest,\
SESSION_SECRET=mosaic-session-secret:latest,\
GCS_BUCKET_NAME=mosaic-gcs-bucket:latest

echo ""
echo "Deployed. Service URL:"
SERVICE_URL=$(gcloud run services describe "$SERVICE" --region "$REGION" --project "$PROJECT" \
  --format "value(status.url)")
echo "$SERVICE_URL"
echo ""
echo "Add this to your OAuth client's authorized redirect URIs:"
echo "  ${SERVICE_URL}/auth/callback"
