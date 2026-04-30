#!/bin/bash
# Run the dashboard locally
# Usage: bash deploy/run_local.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$SCRIPT_DIR/../app"

echo "==> Installing dependencies..."
cd "$APP_DIR"
pip install -q -r requirements.txt

echo "==> Starting dashboard at http://localhost:8080"
echo "    Ctrl+C to stop"
python main.py
