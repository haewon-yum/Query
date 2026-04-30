#!/bin/bash
# One-time GCP bootstrap for Mosaic.
# Run once before first deploy. Safe to re-run — skips already-created resources.
set -euo pipefail

PROJECT="gds-apac"
REGION="asia-northeast3"
BUCKET="gds-apac-html-reports"

BOLD="\033[1m"
GREEN="\033[32m"
RESET="\033[0m"

step() { echo -e "\n${BOLD}▶ $1${RESET}"; }
ok()   { echo -e "${GREEN}  ✓ $1${RESET}"; }

# ─────────────────────────────────────────────
step "1/4  Enabling required GCP APIs"
# ─────────────────────────────────────────────
gcloud services enable \
  run.googleapis.com \
  storage.googleapis.com \
  secretmanager.googleapis.com \
  --project "$PROJECT"
ok "APIs enabled"

# ─────────────────────────────────────────────
step "2/4  Creating GCS bucket"
# ─────────────────────────────────────────────
if gsutil ls -p "$PROJECT" "gs://${BUCKET}" &>/dev/null; then
  ok "Bucket gs://${BUCKET} already exists"
else
  gsutil mb -p "$PROJECT" -l "$REGION" "gs://${BUCKET}"
  ok "Bucket gs://${BUCKET} created"
fi

# ─────────────────────────────────────────────
step "3/4  Creating session secret"
# ─────────────────────────────────────────────
_upsert_secret() {
  local NAME="$1" FILE="$2"
  if gcloud secrets describe "$NAME" --project "$PROJECT" &>/dev/null; then
    gcloud secrets versions add "$NAME" --data-file="$FILE" --project "$PROJECT"
    ok "Secret $NAME — new version added"
  else
    gcloud secrets create "$NAME" --data-file="$FILE" --project "$PROJECT"
    ok "Secret $NAME created"
  fi
}

SESSION_FILE=$(mktemp)
python3 -c "import secrets; print(secrets.token_hex(32), end='')" > "$SESSION_FILE"
_upsert_secret "mosaic-session-secret" "$SESSION_FILE"
rm "$SESSION_FILE"

BUCKET_FILE=$(mktemp)
echo -n "$BUCKET" > "$BUCKET_FILE"
_upsert_secret "mosaic-gcs-bucket" "$BUCKET_FILE"
rm "$BUCKET_FILE"

# ─────────────────────────────────────────────
step "4/4  OAuth client ID (manual step)"
# ─────────────────────────────────────────────
cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 MANUAL: Create OAuth 2.0 Client ID in GCP Console
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 1. Open: https://console.cloud.google.com/apis/credentials?project=${PROJECT}
 2. Create Credentials → OAuth client ID → Web application
 3. Name: Mosaic
 4. Authorized redirect URIs:
      http://localhost:8080/auth/callback        ← local backend
      http://localhost:5173/auth/callback        ← local Vite dev server
      https://<your-cloud-run-url>/auth/callback ← add after first deploy

 5. Copy the Client ID and Secret, then run:

    echo -n 'YOUR_CLIENT_ID' | \\
      gcloud secrets create mosaic-google-client-id --data-file=- --project ${PROJECT}

    echo -n 'YOUR_CLIENT_SECRET' | \\
      gcloud secrets create mosaic-google-client-secret --data-file=- --project ${PROJECT}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Steps 1–3 complete. Finish the OAuth step, then run ./deploy.sh
EOF
