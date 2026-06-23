#!/bin/bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_DIR"

LOG="$REPO_DIR/.update.log"

is_trade_day() {
  PYTHONDONTWRITEBYTECODE=1 python3 - <<'PY'
import datetime
import importlib.util
from pathlib import Path

spec = importlib.util.spec_from_file_location('etf_pipeline', Path('scripts/etf_pipeline.py'))
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
raise SystemExit(0 if mod._is_cn_trade_day() else 1)
PY
}

is_market_window() {
  local hm
  hm="$(TZ=Asia/Shanghai date +%H%M)"
  case "$hm" in
    0930|1000|1030|1100|1130|1300|1330|1400|1430|1500) return 0 ;;
    *) return 1 ;;
  esac
}

if ! is_trade_day; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Skip local fallback: non-trading day" >> "$LOG"
  exit 0
fi

if ! is_market_window; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Skip local fallback: outside scheduled market windows" >> "$LOG"
  exit 0
fi

bash scripts/update.sh
