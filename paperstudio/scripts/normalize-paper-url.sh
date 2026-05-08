#!/usr/bin/env bash
# scripts/normalize-paper-url.sh — convert known paper-page URLs to a direct
# PDF URL that the upstream claude-paper:study downloader can fetch.
#
# Usage: normalize-paper-url.sh <input>
#   - If <input> matches a known paper-host URL, prints the normalized PDF URL.
#   - Otherwise prints <input> unchanged.
#
# Exit code is always 0 — callers should treat unchanged output as "no rule
# matched, pass through to the downloader as-is".
#
# Supported sources:
#   - bioRxiv / medRxiv
#   - OpenReview
#   - ACL Anthology
#   - HuggingFace papers (→ arXiv)
#   - arXiv abs/ → pdf/ (claude-paper handles this too, but we normalize early)

set -euo pipefail

input="${1:-}"
if [[ -z "$input" ]]; then
  echo "usage: normalize-paper-url.sh <input>" >&2
  exit 2
fi

# Strip trailing slash and #fragment for matching, but preserve query string.
url="${input%#*}"
url="${url%/}"

# arXiv abs → pdf
if [[ "$url" =~ ^https?://arxiv\.org/abs/([^?]+) ]]; then
  echo "https://arxiv.org/pdf/${BASH_REMATCH[1]}.pdf"
  exit 0
fi

# HuggingFace papers/<arxiv-id> → arXiv pdf
if [[ "$url" =~ ^https?://huggingface\.co/papers/([0-9.]+) ]]; then
  echo "https://arxiv.org/pdf/${BASH_REMATCH[1]}.pdf"
  exit 0
fi

# bioRxiv / medRxiv content page → .full.pdf
# Examples:
#   https://www.biorxiv.org/content/10.1101/2024.01.01.123456v1
#   https://www.biorxiv.org/content/10.1101/2024.01.01.123456v1.full
if [[ "$url" =~ ^https?://(www\.)?(biorxiv|medrxiv|chemrxiv)\.org/content/(.+) ]]; then
  host="${BASH_REMATCH[2]}"
  path="${BASH_REMATCH[3]}"
  # strip trailing .full / .abstract if present
  path="${path%.full}"
  path="${path%.abstract}"
  echo "https://www.${host}.org/content/${path}.full.pdf"
  exit 0
fi

# OpenReview forum?id=XYZ → pdf?id=XYZ
if [[ "$url" =~ ^https?://openreview\.net/(forum|attachment)\?id=([^&]+) ]]; then
  echo "https://openreview.net/pdf?id=${BASH_REMATCH[2]}"
  exit 0
fi

# ACL Anthology page → page + .pdf (e.g. .../2023.acl-long.123/ → .../2023.acl-long.123.pdf)
if [[ "$url" =~ ^https?://aclanthology\.org/([^/]+)$ ]]; then
  echo "https://aclanthology.org/${BASH_REMATCH[1]}.pdf"
  exit 0
fi

# Pass through.
echo "$input"
