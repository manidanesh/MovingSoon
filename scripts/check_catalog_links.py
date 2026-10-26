#!/usr/bin/env python3
"""Validate the maintained guidance URL inventory; network checks require --live-verify.

Static validation is deterministic and does not claim a link is live. A live run records
actual HTTP status/redirects and failures instead of treating network errors as passing.
Run: python3 scripts/check_catalog_links.py [--live-verify] [--limit N] [--output PATH]
"""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import sys
from urllib.error import HTTPError, URLError
from urllib.parse import urlparse
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "movingsoon.app/Services/CatalogGuidance.swift"
STATES = set("AL AK AZ AR CA CO CT DE FL GA HI ID IL IN IA KS KY LA ME MD MA MI MN MS MO MT NE NV NH NJ NM NY NC ND OH OK OR PA RI SC SD TN TX UT VT VA WA WV WI WY".split())


def dictionary(source: str, name: str) -> dict[str, str]:
    match = re.search(r"\b" + re.escape(name) + r": \[String: String\] = \[(.*?)\n    \]", source, re.S)
    if not match:
        raise ValueError(f"Missing maintained dictionary: {name}")
    pairs = re.findall(r'"([^"\n]+)"\s*:\s*"([^"\n]+)"', match.group(1))
    if len(dict(pairs)) != len(pairs):
        raise ValueError(f"Duplicate identities in {name}")
    return dict(pairs)


def inventory() -> tuple[list[dict[str, str]], list[str]]:
    source = SOURCE.read_text()
    official = dictionary(source, "officialURLs")
    agencies = dictionary(source, "motorVehicleAgencies")
    failures = [f"Missing official DMV region {s}" for s in sorted((STATES | {"DC"}) - agencies.keys())]
    rows = [{"kind": "guidance", "id": key, "url": url} for key, url in sorted(official.items())]
    rows += [{"kind": "motor-vehicle", "id": key, "url": url} for key, url in sorted(agencies.items())]
    # Explicit separate licence/registration routes are also part of the inventory.
    for key, url in re.findall(r'if registration, region == "([A-Z]{2})" \{ return URL\(string: "([^"]+)"\)', source):
        rows.append({"kind": "registration", "id": key, "url": url})
    known = {row["url"] for row in rows}
    for url in sorted(set(re.findall(r'"(https://[^"\n]+)"', source)) - known):
        rows.append({"kind": "support", "id": urlparse(url).netloc, "url": url})
    for row in rows:
        parsed = urlparse(row["url"])
        if parsed.scheme != "https" or not parsed.netloc or parsed.username or parsed.password:
            failures.append(f"Invalid HTTPS URL: {row['id']}: {row['url']}")
        if (parsed.hostname or "").removeprefix("www.") == "dmv.org":
            failures.append(f"Commercial DMV link: {row['id']}")
    return rows, failures


def live_check(row: dict[str, str]) -> dict[str, object]:
    result: dict[str, object] = dict(row)
    last_error = ""
    # Some official sites block HEAD while serving normal GET requests.
    for method in ("HEAD", "GET"):
        request = Request(row["url"], method=method, headers={"User-Agent": "MovingSoon-LinkReview/1.0", "Accept": "text/html,application/pdf;q=0.9,*/*;q=0.5"})
        try:
            with urlopen(request, timeout=15) as response:
                status = response.status
                result.update(status=status, final_url=response.url, method=method,
                              result="reachable" if 200 <= status < 400 else "failed")
                return result
        except HTTPError as error:
            last_error = f"HTTP {error.code}"
            result.update(status=error.code, final_url=error.url, method=method)
        except (URLError, TimeoutError, OSError) as error:
            last_error = str(error)
    # Not found/gone and other permanent 4xx responses are broken links. Access
    # controls/rate limits, transient server errors and transport failures are
    # inaccessible here and do not prove that the official page is missing.
    status = result.get("status")
    broken = isinstance(status, int) and 400 <= status < 500 and status not in (401, 403, 408, 429)
    result.update(result="failed" if broken else "unverified", error=last_error)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--live-verify", action="store_true", help="Opt in to public network requests; failures remain unverified.")
    parser.add_argument("--limit", type=int, default=0, help="Limit live requests to the first N inventory entries (0 = all).")
    parser.add_argument("--kind", choices=("guidance", "motor-vehicle", "registration", "support"),
                        help="Limit live verification to this inventory kind; static validation still checks all entries.")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    rows, failures = inventory()
    results: list[dict[str, object]] = [dict(row, result="static-only") for row in rows]
    if args.live_verify:
        indices = [index for index, row in enumerate(rows) if not args.kind or row["kind"] == args.kind]
        if args.limit > 0:
            indices = indices[:args.limit]
        selected = [rows[index] for index in indices]
        with ThreadPoolExecutor(max_workers=4) as pool:
            checked = list(pool.map(live_check, selected))
        for index, check in zip(indices, checked):
            results[index] = check
    report = {"mode": "live" if args.live_verify else "static", "static_errors": failures,
              "inventory_count": len(rows), "results": results}
    if args.live_verify:
        report["checked_at_utc"] = datetime.now(timezone.utc).isoformat()
    serialized = json.dumps(report, indent=2) + "\n"
    if args.output:
        args.output.write_text(serialized)
    counts = {label: sum(row["result"] == label for row in results) for label in ("static-only", "reachable", "unverified", "failed")}
    print(json.dumps({"mode": report["mode"], "inventory_count": len(rows), "static_errors": failures, "counts": counts}, indent=2))
    for row in results:
        if row["result"] in ("unverified", "failed"):
            print(f"{row['result'].upper()} {row['kind']} {row['id']}: {row.get('error', row.get('status'))}")
    return 1 if failures or any(row["result"] in ("unverified", "failed") for row in results) else 0


if __name__ == "__main__":
    sys.exit(main())
