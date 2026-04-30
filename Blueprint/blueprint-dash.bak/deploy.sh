#!/bin/bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

PROJECT="gds-apac"
REGION="asia-northeast3"
SERVICE="blueprint"
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
  --min-instances 1 \
  --max-instances 3 \
  --set-secrets \
    GOOGLE_CLIENT_ID=blueprint-google-client-id:latest,\
GOOGLE_CLIENT_SECRET=blueprint-google-client-secret:latest,\
SESSION_SECRET=blueprint-session-secret:latest,\
BLUEPRINT_NOTES_SHEET_ID=blueprint-notes-sheet-id:latest

echo ""
echo "Deployed. Service URL:"
SERVICE_URL=$(gcloud run services describe "$SERVICE" \
  --region "$REGION" --project "$PROJECT" \
  --format "value(status.url)")
echo "$SERVICE_URL"
echo ""
echo "Set APP_BASE_URL env var if not already set:"
echo "  gcloud run services update $SERVICE --region $REGION --project $PROJECT \\"
echo "    --set-env-vars APP_BASE_URL=${SERVICE_URL}"
echo ""
echo "Add this to the OAuth client's authorized redirect URIs:"
echo "  ${SERVICE_URL}/auth/callback"
