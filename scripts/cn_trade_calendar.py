#!/usr/bin/env python3
from __future__ import annotations

import datetime
import json
import logging
import sys
from pathlib import Path
from typing import Set

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
    stream=sys.stdout,
)
log = logging.getLogger("cn_trade_calendar")

SCRIPT_DIR = Path(__file__).resolve().parent
CACHE_FILE = SCRIPT_DIR / "cn-trade-dates.json"
BJT = datetime.timezone(datetime.timedelta(hours=8))


def fetch_trade_dates() -> Set[str]:
    import akshare as ak

    df = ak.tool_trade_date_hist_sina()
    if "trade_date" not in df.columns:
        raise RuntimeError("trade_date column missing")

    dates = set()
    for raw in df["trade_date"].dropna().tolist():
        if isinstance(raw, datetime.datetime):
            dates.add(raw.date().isoformat())
        elif isinstance(raw, datetime.date):
            dates.add(raw.isoformat())
        else:
            dates.add(str(raw)[:10])
    return dates


def write_cache(dates: Set[str]) -> None:
    payload = {
        "generated_at": datetime.datetime.now(BJT).isoformat(timespec="seconds"),
        "trade_dates": sorted(dates),
    }
    CACHE_FILE.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    log.info(f"已写入交易日历缓存: {CACHE_FILE} ({len(dates)} 个交易日)")


def main() -> None:
    dates = fetch_trade_dates()
    write_cache(dates)


if __name__ == "__main__":
    main()
