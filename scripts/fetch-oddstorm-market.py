#!/usr/bin/env python3

"""Fetch a named-bookmaker football snapshot from OddStorm public pages."""

import argparse
import html
from html.parser import HTMLParser
import json
import math
import re
import sys
from datetime import datetime, timezone
from urllib.request import Request, urlopen


USER_AGENT = "Mozilla/5.0 (compatible; EloMLResearch/1.0)"


def fetch(url, timeout):
    request = Request(url, headers={"User-Agent": USER_AGENT})
    with urlopen(request, timeout=timeout) as response:
        return response.read().decode("utf-8", errors="replace")


def normalize(value):
    return re.sub(r"[^a-z0-9]", "", html.unescape(value).lower())


class RowParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.rows = []
        self.row = None
        self.cell = None
        self.cell_parts = []

    def handle_starttag(self, tag, attrs):
        if tag == "tr":
            self.row = []
        elif tag in ("td", "th") and self.row is not None:
            self.cell = tag
            self.cell_parts = []

    def handle_data(self, data):
        if self.cell is not None:
            self.cell_parts.append(data)

    def handle_endtag(self, tag):
        if tag in ("td", "th") and self.cell == tag:
            text = " ".join("".join(self.cell_parts).split())
            self.row.append(html.unescape(text))
            self.cell = None
            self.cell_parts = []
        elif tag == "tr" and self.row is not None:
            if self.row:
                self.rows.append(self.row)
            self.row = None


def parse_rows(document):
    parser = RowParser()
    parser.feed(document)
    return parser.rows


def find_match_href(document, home, away):
    pattern = re.compile(r'<a href="([^"]+/odds/match/[^"]+|/odds/match/[^"]+)">([^<]+)</a>')
    home_key = normalize(home)
    away_key = normalize(away)
    for href, label in pattern.findall(document):
        label_key = normalize(label)
        if home_key in label_key and away_key in label_key:
            return href
    raise RuntimeError(f"Could not find {home} vs {away} on OddStorm league page")


def bookmaker_row(document, bookmaker, expected_values):
    target = normalize(bookmaker)
    for row in parse_rows(document):
        if row and normalize(row[0]) == target:
            numbers = []
            for value in row[1:]:
                try:
                    numbers.append(float(value))
                except ValueError:
                    pass
            if len(numbers) >= expected_values:
                return numbers
    raise RuntimeError(f"Could not find complete {bookmaker} row")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--league-id", required=True)
    parser.add_argument("--league-slug", required=True)
    parser.add_argument("--home", required=True)
    parser.add_argument("--away", required=True)
    parser.add_argument("--bookmaker", default="Pinnacle")
    parser.add_argument("--timeout", type=int, default=30)
    args = parser.parse_args()

    league_url = f"https://www.oddstorm.com/odds/league/{args.league_id}-{args.league_slug}"
    asian_url = f"https://www.oddstorm.com/asianodds/league/{args.league_id}-{args.league_slug}"
    league_html = fetch(league_url, args.timeout)
    href = find_match_href(league_html, args.home, args.away)
    if href.startswith("/"):
        match_url = "https://www.oddstorm.com" + href
    else:
        match_url = href

    one_x_two = bookmaker_row(fetch(match_url + "/1x2", args.timeout), args.bookmaker, 3)
    totals = bookmaker_row(fetch(match_url + "/over-under?h=2.5", args.timeout), args.bookmaker, 3)
    if abs(totals[0] - 2.5) > 1e-6:
        raise RuntimeError("OddStorm totals row is not the 2.5 line")

    home_key = normalize(args.home)
    away_key = normalize(args.away)
    asian_candidates = []
    for row in parse_rows(fetch(asian_url, args.timeout)):
        if len(row) < 5:
            continue
        label_key = normalize(row[1])
        if home_key not in label_key or away_key not in label_key:
            continue
        try:
            home_price = float(row[2])
            line = float(row[3])
            away_price = float(row[4])
        except ValueError:
            continue
        if 1.5 <= home_price <= 2.6 and 1.5 <= away_price <= 2.6:
            balance = abs(math.log(home_price / away_price))
            asian_candidates.append((balance, line, home_price, away_price))
    if not asian_candidates:
        raise RuntimeError("Could not determine a balanced Asian handicap line")
    _, asian_line, asian_home, asian_away = min(asian_candidates)

    result = {
        "source": "OddStorm",
        "retrieved_at_utc": datetime.now(timezone.utc).isoformat(),
        "league_url": league_url,
        "asian_url": asian_url,
        "match_url": match_url,
        "bookmaker": args.bookmaker,
        "home_team": args.home,
        "away_team": args.away,
        "home_odds": one_x_two[0],
        "draw_odds": one_x_two[1],
        "away_odds": one_x_two[2],
        "over_2_5_odds": totals[1],
        "under_2_5_odds": totals[2],
        "asian_line_home": asian_line,
        "asian_home_price": asian_home,
        "asian_away_price": asian_away,
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"fetch-oddstorm-market: {error}", file=sys.stderr)
        raise SystemExit(1)
