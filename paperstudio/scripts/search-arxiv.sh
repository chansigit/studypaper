#!/usr/bin/env bash
# scripts/search-arxiv.sh — search arXiv by title / free-text query.
#
# Usage: search-arxiv.sh "<query>" [max_results]
#
# Output: TSV, one result per line:
#   <arxiv-id>\t<year>\t<authors-short>\t<title>\t<pdf-url>
#
# Exits 0 if at least one result, 1 if zero results, 2 on usage / network error.
#
# Uses arXiv public Atom API (no key, no rate-limit issues for low volume).
# Requires: curl, sed, awk. No XML parser dependency — uses tag-line greps.

set -euo pipefail

query="${1:-}"
max="${2:-5}"

if [[ -z "$query" ]]; then
  echo "usage: search-arxiv.sh \"<query>\" [max_results]" >&2
  exit 2
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "search-arxiv.sh: curl is required" >&2
  exit 2
fi

# URL-encode the query (preserve spaces as +).
encoded=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote_plus(sys.argv[1]))" "$query" 2>/dev/null \
  || printf '%s' "$query" | sed 's/ /+/g; s/&/%26/g')

api="https://export.arxiv.org/api/query?search_query=all:${encoded}&max_results=${max}&sortBy=relevance"

ua="paperstudio/0.4.0 (https://github.com/chansigit/studypaper)"
curl_out=$(curl -sSL --max-time 20 -A "$ua" -o /tmp/paperstudio-arxiv-$$.xml -w 'CODE=%{http_code}' "$api" 2>/dev/null || echo "CODE=000")
http_code=$(printf '%s' "$curl_out" | grep -oE 'CODE=[0-9]+' | tail -1 | sed 's/CODE=//')
[[ -z "$http_code" ]] && http_code="000"
xml=$(cat /tmp/paperstudio-arxiv-$$.xml 2>/dev/null || true)
rm -f /tmp/paperstudio-arxiv-$$.xml

case "$http_code" in
  200) ;;
  429) echo "search-arxiv.sh: arXiv API rate-limited (HTTP 429). Retry in ~60s." >&2; exit 2 ;;
  000) echo "search-arxiv.sh: arXiv API request failed (network)." >&2; exit 2 ;;
  *)   echo "search-arxiv.sh: arXiv API returned HTTP $http_code." >&2; exit 2 ;;
esac

# Split into entries. arXiv Atom puts each result inside <entry>...</entry>.
# Use awk to split on </entry>; each chunk has one paper.
echo "$xml" | awk 'BEGIN{RS="</entry>"} /<entry>/' | while IFS= read -r entry; do
  [[ -z "$entry" ]] && continue

  # arXiv id is in <id>http://arxiv.org/abs/2401.12345v2</id>
  id=$(echo "$entry" | grep -oE '<id>http[^<]+</id>' | head -1 \
    | sed 's|<id>http://arxiv.org/abs/||; s|</id>||; s|v[0-9]*$||')
  [[ -z "$id" ]] && continue

  # Title: collapse whitespace inside <title>...</title>
  title=$(echo "$entry" | tr '\n' ' ' \
    | grep -oE '<title>[^<]+</title>' | head -1 \
    | sed 's|<title>||; s|</title>||' \
    | sed 's/  */ /g; s/^ //; s/ $//')

  # Year from <published>2024-01-15T...</published>
  year=$(echo "$entry" | grep -oE '<published>[0-9]{4}' | head -1 | sed 's|<published>||')

  # First author <name>...</name>
  first_author=$(echo "$entry" | grep -oE '<name>[^<]+</name>' | head -1 \
    | sed 's|<name>||; s|</name>||')
  author_count=$(echo "$entry" | grep -cE '<name>[^<]+</name>' || true)
  if [[ "${author_count:-0}" -gt 1 ]]; then
    authors="${first_author} et al."
  else
    authors="${first_author}"
  fi

  pdf="https://arxiv.org/pdf/${id}.pdf"

  printf '%s\t%s\t%s\t%s\t%s\n' "$id" "${year:-}" "${authors:-}" "${title:-}" "$pdf"
done | head -n "$max" | awk 'BEGIN{n=0} {print; n++} END{exit (n>0?0:1)}'
