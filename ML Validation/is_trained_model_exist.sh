#!/usr/bin/env bash
set -euo pipefail

BUCKET="gs://tfserving-us"
MODEL_GLOB="revenue*"

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <bundle> <event>"
  echo "Example: $0 com.gm11.bingocraze purchase"
  exit 1
fi

BUNDLE="$1"
EVENT="$2"

# 정규식 escape
ESC_BUNDLE="$(printf '%s' "$BUNDLE" | sed 's/[.[\^$*+?(){|\\]/\\&/g')"
ESC_EVENT="$(printf '%s' "$EVENT"  | sed 's/[.[\^$*+?(){|\\]/\\&/g')"
REGEX="^${ESC_BUNDLE}:(android|ios):${ESC_EVENT}$"

# 모델별 최신 timestamp 폴더 수집
LATEST_TS_PATHS="$(
  gcloud storage ls "${BUCKET}/${MODEL_GLOB}/" 2>/dev/null \
  | sed 's:/*$::' \
  | awk '
      {
        p=$0
        n=split(p, a, "/")
        ts=a[n]
        model=a[n-1]
        if (ts ~ /^[0-9]+$/) {
          if (!(model in max) || ts > max[model]) {
            max[model]=ts
            path[model]=p
          }
        }
      }
      END { for (m in path) print path[m] }
    '
)"

# FOUND 된 경우만 출력
echo "${LATEST_TS_PATHS}" | while IFS= read -r TS_DIR; do
  FILE_PATH="${TS_DIR}/assets.extra/trained_bundles.txt"

  # 파일 없으면 조용히 skip
  if ! gcloud storage ls "${FILE_PATH}" >/dev/null 2>&1; then
    continue
  fi

  # 매칭 없으면 skip
  MATCHES="$(gcloud storage cat "${FILE_PATH}" | grep -E "${REGEX}" || true)"
  [[ -z "${MATCHES}" ]] && continue

  # 여기까지 왔으면 "파일 있음 + 매칭 있음"
  echo "FOUND in ${TS_DIR}"
  echo "${MATCHES}" | sed 's/^/  - /'
done
