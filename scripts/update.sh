#!/bin/bash
# Fetch ETF + macro data, commit & push to GitHub (used by Actions + optional local cron)
#
# Local cron example (A 股交易时段 on weekdays):
#   30 9 * * 1-5  cd /path/to/data && bash scripts/update.sh >> .update.log 2>&1
#   0,30 10-11 * * 1-5  cd /path/to/data && bash scripts/update.sh >> .update.log 2>&1
#   0,30 13-14 * * 1-5  cd /path/to/data && bash scripts/update.sh >> .update.log 2>&1
#   0 15 * * 1-5  cd /path/to/data && bash scripts/update.sh >> .update.log 2>&1

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_DIR"

PYTHON="${PYTHON:-python3}"
LOG="$REPO_DIR/.update.log"
USE_LOG=$([ -n "${GITHUB_ACTIONS:-}" ] && echo 0 || echo 1)

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  echo "$msg"
  if [ "$USE_LOG" = "1" ]; then
    echo "$msg" >> "$LOG"
  fi
}

run_pipeline() {
  set +e
  if [ "$USE_LOG" = "1" ]; then
    "$PYTHON" "$@" >> "$LOG" 2>&1
  else
    "$PYTHON" "$@"
  fi
  local rc=$?
  set -e
  return "$rc"
}

if [ "${SKIP_GIT_PULL:-0}" != "1" ]; then
  log "Syncing main..."
  git pull --rebase origin main
fi

ETF_OK=0
MACRO_OK=0

log "Running ETF pipeline..."
if run_pipeline scripts/etf_pipeline.py --json-out public/etf-data.json; then
  ETF_OK=1
else
  log "ETF pipeline failed (exit $?)"
fi

log "Running macro pipeline..."
if run_pipeline scripts/macro_pipeline.py --json-out public/macro-data.json; then
  MACRO_OK=1
else
  log "Macro pipeline failed (exit $?)"
fi

if [ "$ETF_OK" = "0" ] && [ "$MACRO_OK" = "0" ]; then
  log "Both pipelines failed — aborting"
  exit 1
fi

log "Pipeline result: ETF=$ETF_OK MACRO=$MACRO_OK"

git config user.name  "${GIT_AUTHOR_NAME:-github-actions[bot]}"
git config user.email "${GIT_AUTHOR_EMAIL:-github-actions[bot]@users.noreply.github.com}"

git add public/etf-data.json public/macro-data.json
if git diff --staged --quiet; then
  log "No file changes — skip commit"
  exit 0
fi

git commit -m "data: update $(date -u +'%Y-%m-%d %H:%M UTC')"

for attempt in 1 2 3; do
  if git push origin HEAD:main; then
    log "Pushed successfully"
    exit 0
  fi
  log "Push failed, rebasing (attempt ${attempt})"
  git pull --rebase origin main
done

log "Push failed after 3 attempts"
exit 1
