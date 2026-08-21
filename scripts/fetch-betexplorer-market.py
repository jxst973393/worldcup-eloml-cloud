#!/usr/bin/env python3

"""Fetch a second named-bookmaker snapshot from BetExplorer public endpoints."""

import argparse
import html
from html.parser import HTMLParser
import json
import re
import sys
from datetime import datetime, timezone
from urllib.parse import urljoin
from urllib.request import Request, urlopen


USER_AGENT = "Mozilla/5.0 (compatible; EloMLResearch/1.0)"
BASE_URL = "https://www.betexplorer.com/"


def fetch(url, timeout, referer=None):
    headers = {"User-Agent": USER_AGENT, "X-Requested-With": "XMLHttpRequest"}
    if referer:
        headers["Referer"] = referer
    request = Request(url, headers=headers)
    with urlopen(request, timeout=timeout) as response:
        return response.read().decode("utf-8", errors="replace")


def normalize(value):
    value = html.unescape(value).lower()
    value = re.sub(r"\butd\b", "united", value)
    value = re.sub(r"\b(fc|afc|cf)\b", "", value)
    key = re.sub(r"[^a-z0-9]", "", value)
    aliases = {
        "manunited": "manchesterunited",
        "manutd": "manchesterunited",
    }
    return aliases.get(key, key)


def same_team(left, right):
    left_key = normalize(left)
    right_key = normalize(right)
    if left_key == right_key:
        return True
    shorter, longer = sorted((left_key, right_key), key=len)
    return len(shorter) >= 4 and longer.startswith(shorter) and len(longer) - len(shorter) <= 4


class OddsRowParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.rows = []
        self.table_handicap = None
        self.row = None

    def handle_starttag(self, tag, attrs):
        values = dict(attrs)
        if tag == "table":
            self.table_handicap = values.get("data-handicap")
        elif tag == "tr":
            self.row = {"bookmaker": None, "handicap": self.table_handicap, "odds": [], "created": []}
        elif self.row is not None:
            bookmaker = values.get("data-bookie")
            odd = values.get("data-odd")
            created = values.get("data-created")
            if bookmaker:
                self.row["bookmaker"] = bookmaker
            if odd:
                try:
                    self.row["odds"].append(float(odd))
                    self.row["created"].append(created or "")
                except ValueError:
                    pass

    def handle_endtag(self, tag):
        if tag == "tr" and self.row is not None:
            if self.row["odds"]:
                self.rows.append(self.row)
            self.row = None
        elif tag == "table":
            self.table_handicap = None


def find_fixture(fixtures_html, home, away):
    pattern = re.compile(
        r'<a href="([^"]+)"[^>]*class="in-match"[^>]*>\s*<span>([^<]+)</span>\s*-\s*<span>([^<]+)</span>',
        re.I,
    )
    for href, listed_home, listed_away in pattern.findall(fixtures_html):
        if same_team(listed_home, home) and same_team(listed_away, away):
            event_id = href.rstrip("/").split("/")[-1]
            return urljoin(BASE_URL, href), event_id
    raise RuntimeError(f"Could not find {home} vs {away} on BetExplorer fixtures page")


def odds_rows(document):
    parser = OddsRowParser()
    parser.feed(document)
    return parser.rows


def select_row(rows, bookmaker, count, handicap=None):
    target = normalize(bookmaker)
    for row in rows:
        if normalize(row["bookmaker"] or "") != target:
            continue
        if handicap is not None:
            try:
                if abs(float(row["handicap"]) - float(handicap)) > 1e-9:
                    continue
            except (TypeError, ValueError):
                continue
        if len(row["odds"]) >= count:
            return row
    condition = f" at handicap {handicap}" if handicap is not None else ""
    raise RuntimeError(f"Could not find {bookmaker} row{condition}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--league-path", required=True, help="Example: football/england/premier-league")
    parser.add_argument("--home", required=True)
    parser.add_argument("--away", required=True)
    parser.add_argument("--bookmaker", default="bet365")
    parser.add_argument("--timeout", type=int, default=30)
    args = parser.parse_args()

    league_path = args.league_path.strip("/")
    fixtures_url = f"{BASE_URL}{league_path}/fixtures/"
    match_url, event_id = find_fixture(fetch(fixtures_url, args.timeout), args.home, args.away)

    def endpoint(bet_type):
        return f"{BASE_URL}match-odds/{event_id}/0/{bet_type}/bestOdds/?lang=en"

    one_x_two_url = endpoint("1x2")
    totals_url = endpoint("ou")
    one_x_two_json = json.loads(fetch(one_x_two_url, args.timeout, match_url))
    totals_json = json.loads(fetch(totals_url, args.timeout, match_url))
    one_x_two = select_row(odds_rows(one_x_two_json["odds"]), args.bookmaker, 3)
    totals = select_row(odds_rows(totals_json["odds"]), args.bookmaker, 2, "2.5")

    result = {
        "source": "BetExplorer",
        "retrieved_at_utc": datetime.now(timezone.utc).isoformat(),
        "fixtures_url": fixtures_url,
        "match_url": match_url,
        "one_x_two_endpoint": one_x_two_url,
        "totals_endpoint": totals_url,
        "event_id": event_id,
        "bookmaker": args.bookmaker,
        "home_team": args.home,
        "away_team": args.away,
        "home_odds": one_x_two["odds"][0],
        "draw_odds": one_x_two["odds"][1],
        "away_odds": one_x_two["odds"][2],
        "over_2_5_odds": totals["odds"][0],
        "under_2_5_odds": totals["odds"][1],
        "one_x_two_created": one_x_two["created"][:3],
        "totals_created": totals["created"][:2],
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"fetch-betexplorer-market: {error}", file=sys.stderr)
        raise SystemExit(1)
