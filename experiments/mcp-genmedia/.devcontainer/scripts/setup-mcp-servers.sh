#!/usr/bin/env bash
set -euo pipefail

echo "Setting up MCP Genmedia development environment..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

if [[ ! -d "${WORKSPACE_DIR}/mcp-genmedia-go" ]]; then
  echo "Expected mcp-genmedia-go under ${WORKSPACE_DIR}."
  exit 1
fi

for cmd in npm go python3; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "Missing required command: ${cmd}"
    exit 1
  fi
done

mkdir -p "${HOME}/.config/mcp" "${HOME}/.gemini/extensions/google-genmedia-extension"

# Install commonly used MCP utility servers for local agent workflows.
npm install -g \
  @modelcontextprotocol/server-filesystem \
  @modelcontextprotocol/server-memory \
  @modelcontextprotocol/server-brave-search

# Build and install Genmedia MCP Go servers from the local checkout.
pushd "${WORKSPACE_DIR}/mcp-genmedia-go" >/dev/null
go work sync
go install ./mcp-avtool-go ./mcp-chirp3-go ./mcp-imagen-go ./mcp-lyria-go ./mcp-veo-go
popd >/dev/null

# Python dependencies used by sample agents and scripts.
python3 -m venv "${WORKSPACE_DIR}/.venv"
"${WORKSPACE_DIR}/.venv/bin/python" -m pip install --upgrade pip
"${WORKSPACE_DIR}/.venv/bin/python" -m pip install -r "${WORKSPACE_DIR}/requirements.txt"

# Create a default MCP host configuration that points to installed binaries.
cat > "${HOME}/.config/mcp/config.json" <<EOF_JSON
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["@modelcontextprotocol/server-filesystem", "${WORKSPACE_DIR}"]
    },
    "memory": {
      "command": "npx",
      "args": ["@modelcontextprotocol/server-memory"]
    },
    "brave-search": {
      "command": "npx",
      "args": ["@modelcontextprotocol/server-brave-search"],
      "env": {
        "BRAVE_API_KEY": ""
      }
    },
    "mcp-imagen-go": {
      "command": "${HOME}/go/bin/mcp-imagen-go",
      "env": {
        "PROJECT_ID": "${PROJECT_ID:-}",
        "LOCATION": "${LOCATION:-us-central1}",
        "GENMEDIA_BUCKET": "${GENMEDIA_BUCKET:-}"
      }
    },
    "mcp-veo-go": {
      "command": "${HOME}/go/bin/mcp-veo-go",
      "env": {
        "PROJECT_ID": "${PROJECT_ID:-}",
        "LOCATION": "${LOCATION:-us-central1}",
        "GENMEDIA_BUCKET": "${GENMEDIA_BUCKET:-}"
      }
    },
    "mcp-chirp3-go": {
      "command": "${HOME}/go/bin/mcp-chirp3-go",
      "env": {
        "PROJECT_ID": "${PROJECT_ID:-}",
        "LOCATION": "${LOCATION:-us-central1}",
        "GENMEDIA_BUCKET": "${GENMEDIA_BUCKET:-}"
      }
    },
    "mcp-lyria-go": {
      "command": "${HOME}/go/bin/mcp-lyria-go",
      "env": {
        "PROJECT_ID": "${PROJECT_ID:-}",
        "LOCATION": "${LOCATION:-us-central1}",
        "GENMEDIA_BUCKET": "${GENMEDIA_BUCKET:-}"
      }
    },
    "mcp-avtool-go": {
      "command": "${HOME}/go/bin/mcp-avtool-go",
      "env": {
        "PROJECT_ID": "${PROJECT_ID:-}",
        "LOCATION": "${LOCATION:-us-central1}",
        "GENMEDIA_BUCKET": "${GENMEDIA_BUCKET:-}"
      }
    }
  }
}
EOF_JSON

echo "MCP Genmedia setup complete."
echo "- Go binaries installed in ${HOME}/go/bin"
echo "- MCP config written to ${HOME}/.config/mcp/config.json"
echo "- Python venv created at ${WORKSPACE_DIR}/.venv"
