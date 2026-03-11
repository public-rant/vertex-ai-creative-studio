#!/usr/bin/env bash
set -euo pipefail

avtool --version
jq -e '.mcpServers["genmedia-avtool"]' ~/.gemini/settings.json >/dev/null

echo "avtool-only scenario checks passed"
