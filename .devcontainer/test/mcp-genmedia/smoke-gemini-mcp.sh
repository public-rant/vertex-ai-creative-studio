#!/usr/bin/env bash
set -euo pipefail

command -v gemini >/dev/null
command -v avtool >/dev/null
jq -e '.mcpServers["genmedia-avtool"]' ~/.gemini/settings.json >/dev/null

echo "Gemini + MCP config looks ready."
if [[ -z "${GEMINI_API_KEY:-}" ]]; then
  echo "GEMINI_API_KEY is not set; skipping live chat smoke."
  exit 0
fi

echo "GEMINI_API_KEY detected. Run an interactive smoke check with:"
echo "  gemini"
echo "Then try prompt: 'Use the genmedia-avtool MCP server to outline a basic image generation workflow.'"
