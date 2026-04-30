#!/bin/bash
# One-time GCP setup for the Blueprint Cloud Run service.
# Run once before the first deploy.
set -euo pipefail

PROJECT="gds-apac"

echo "Enabling required APIs…"
gcloud services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  secretmanager.googleapis.com \
  sheets.googleapis.com \
  --project "$PROJECT"

echo ""
echo "Creating Secret Manager secrets…"
echo "You will be prompted to enter each secret value."

read -rsp "GOOGLE_CLIENT_ID: " CLIENT_ID && echo
echo -n "$CLIENT_ID" | gcloud secrets create blueprint-google-client-id \
  --data-file=- --project "$PROJECT" 2>/dev/null || \
  echo -n "$CLIENT_ID" | gcloud secrets versions add blueprint-google-client-id \
    --data-file=- --project "$PROJECT"

read -rsp "GOOGLE_CLIENT_SECRET: " CLIENT_SECRET && echo
echo -n "$CLIENT_SECRET" | gcloud secrets create blueprint-google-client-secret \
  --data-file=- --project "$PROJECT" 2>/dev/null || \
  echo -n "$CLIENT_SECRET" | gcloud secrets versions add blueprint-google-client-secret \
    --data-file=- --project "$PROJECT"

SESSION_SECRET=$(python3 -c "import secrets; print(secrets.token_hex(32))")
echo "Generated SESSION_SECRET: $SESSION_SECRET"
echo -n "$SESSION_SECRET" | gcloud secrets create blueprint-session-secret \
  --data-file=- --project "$PROJECT" 2>/dev/null || \
  echo -n "$SESSION_SECRET" | gcloud secrets versions add blueprint-session-secret \
    --data-file=- --project "$PROJECT"

NOTES_SHEET_ID="1yzriLZh1vgQtTv5xTAlDBaiQ4GzHW8D9fKyOcEtTWUU"
echo -n "$NOTES_SHEET_ID" | gcloud secrets create blueprint-notes-sheet-id \
  --data-file=- --project "$PROJECT" 2>/dev/null || \
  echo -n "$NOTES_SHEET_ID" | gcloud secrets versions add blueprint-notes-sheet-id \
    --data-file=- --project "$PROJECT"

echo ""
echo "Granting compute SA access to secrets…"
SA="326198683934-compute@developer.gserviceaccount.com"
for SECRET in blueprint-google-client-id blueprint-google-client-secret \
              blueprint-session-secret blueprint-notes-sheet-id; do
  gcloud secrets add-iam-policy-binding "$SECRET" \
    --member="serviceAccount:${SA}" \
    --role="roles/secretmanager.secretAccessor" \
    --project "$PROJECT"
done

echo ""
echo "Setup complete. Run ./deploy.sh to build and deploy."
echo ""
echo "Remaining manual steps:"
echo "  1. Share the Notes sheet with ${SA} as Editor"
echo "  2. Add <Cloud Run URL>/auth/callback to the OAuth client redirect URIs"
