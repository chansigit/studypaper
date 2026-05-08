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
if [[ "$url" =~ ^https?://(www\.)?(biorxiv|medrxiv)\.org/content/(.+) ]]; then
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

# NeurIPS new layout: proceedings.neurips.cc/paper_files/paper/<year>/hash/<id>-Abstract[-Conference].html
#   → proceedings.neurips.cc/paper_files/paper/<year>/file/<id>-Paper[-Conference].pdf
if [[ "$url" =~ ^https?://proceedings\.neurips\.cc/paper_files/paper/([0-9]+)/hash/([^/]+)-Abstract(-Conference)?\.html$ ]]; then
  year="${BASH_REMATCH[1]}"
  id="${BASH_REMATCH[2]}"
  suffix="${BASH_REMATCH[3]}"   # may be empty or "-Conference"
  echo "https://proceedings.neurips.cc/paper_files/paper/${year}/file/${id}-Paper${suffix}.pdf"
  exit 0
fi

# NeurIPS legacy: papers.nips.cc/paper/<year>/hash/<id>-Abstract.html
#   → papers.nips.cc/paper/<year>/file/<id>-Paper.pdf
if [[ "$url" =~ ^https?://papers\.nips\.cc/paper/([0-9]+)/hash/([^/]+)-Abstract\.html$ ]]; then
  echo "https://papers.nips.cc/paper/${BASH_REMATCH[1]}/file/${BASH_REMATCH[2]}-Paper.pdf"
  exit 0
fi

# PMLR (ICML / AISTATS / etc.): proceedings.mlr.press/v<vol>/<name>.html
#   → proceedings.mlr.press/v<vol>/<name>/<name>.pdf
if [[ "$url" =~ ^https?://proceedings\.mlr\.press/(v[0-9]+)/([^/]+)\.html$ ]]; then
  vol="${BASH_REMATCH[1]}"
  name="${BASH_REMATCH[2]}"
  echo "https://proceedings.mlr.press/${vol}/${name}/${name}.pdf"
  exit 0
fi

# Pass through.
echo "$input"
