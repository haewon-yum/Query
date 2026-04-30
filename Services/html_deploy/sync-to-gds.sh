#!/usr/bin/env bash
# Sync html_deploy/ → moloco/gds projects/google_cloud_run/mosaic/
# Usage: bash sync-to-gds.sh ["commit message"]

set -e

GDS_CLONE="/tmp/gds-mosaic-sync"
TARGET="$GDS_CLONE/projects/google_cloud_run/mosaic"
SOURCE="$(cd "$(dirname "$0")" && pwd)"
BRANCH="haewon/mosaic-sync"
MSG="${1:-sync: update mosaic from local $(date '+%Y-%m-%d %H:%M')}"

# Re-clone if the temp dir is gone
if [ ! -d "$GDS_CLONE/.git" ]; then
  echo "▶ Cloning moloco/gds (sparse)..."
  git clone --depth=1 --filter=blob:none --sparse https://github.com/moloco/gds.git "$GDS_CLONE"
  cd "$GDS_CLONE"
  git sparse-checkout set projects/google_cloud_run
  git fetch origin
  git checkout -b "$BRANCH" origin/main 2>/dev/null || git checkout "$BRANCH"
else
  cd "$GDS_CLONE"
  git fetch origin
  if git show-ref --verify --quiet refs/heads/"$BRANCH"; then
    git checkout "$BRANCH"
    git rebase origin/main 2>/dev/null || true
  else
    git checkout -b "$BRANCH" origin/main
  fi
fi

mkdir -p "$TARGET"

echo "▶ Rsyncing files..."
rsync -av --delete \
  --exclude='.git' \
  --exclude='.venv' \
  --exclude='__pycache__' \
  --exclude='*.pyc' \
  --exclude='.DS_Store' \
  --exclude='.claude' \
  --exclude='node_modules' \
  --exclude='frontend/dist' \
  --exclude='backend/static' \
  "$SOURCE/" "$TARGET/"

cd "$GDS_CLONE"
git add "$TARGET"

if git diff --cached --quiet; then
  echo "✅ No changes to sync."
  exit 0
fi

git commit -m "$MSG"
git push -u origin "$BRANCH"
echo "✅ Pushed to moloco/gds branch: $BRANCH"
echo "   Open a PR at: https://github.com/moloco/gds/compare/$BRANCH"
