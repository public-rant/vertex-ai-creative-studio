#!/usr/bin/env bash
set -euo pipefail

command -v avtool
command -v gemini
jq -e '.mcpServers["genmedia-avtool"].command == "avtool"' ~/.gemini/settings.json >/dev/null

echo "mcp-genmedia default scenario checks passed"
