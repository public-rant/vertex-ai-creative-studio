#!/usr/bin/env bash
set -euo pipefail

INSTALL_ALL="${INSTALLALL:-false}"
INSTALL_AVTOOL="${INSTALLAVTOOL:-true}"
INSTALL_GCLOUD="${INSTALLGOOGLECLOUDCLI:-false}"
INSTALL_NODE="${INSTALLNODE:-true}"
INSTALL_GEMINI="${INSTALLGEMINICLI:-true}"

if [[ "${INSTALL_ALL}" == "true" ]]; then
  INSTALL_AVTOOL=true
  INSTALL_GCLOUD=true
  INSTALL_NODE=true
  INSTALL_GEMINI=true
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends ca-certificates curl jq git

if [[ "${INSTALL_NODE}" == "true" ]]; then
  if ! command -v node >/dev/null 2>&1; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y --no-install-recommends nodejs
  fi
fi

if [[ "${INSTALL_GCLOUD}" == "true" ]]; then
  if ! command -v gcloud >/dev/null 2>&1; then
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
      | tee /etc/apt/sources.list.d/google-cloud-sdk.list >/dev/null
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
      | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
    apt-get update
    apt-get install -y --no-install-recommends google-cloud-cli
  fi
fi

if [[ "${INSTALL_GEMINI}" == "true" ]]; then
  if ! command -v npm >/dev/null 2>&1; then
    echo "npm is required to install Gemini CLI" >&2
    exit 1
  fi
  npm install -g @google/gemini-cli
fi

if [[ "${INSTALL_AVTOOL}" == "true" ]]; then
  if ! command -v python3 >/dev/null 2>&1; then
    apt-get install -y --no-install-recommends python3 python3-venv
  fi
  cat >/usr/local/bin/avtool <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "--version" ]]; then
  echo "avtool 0.1.0"
  exit 0
fi

echo "avtool placeholder: implement concrete MCP-backed commands in follow-up"
EOS
  chmod +x /usr/local/bin/avtool
fi

TARGET_HOME="${_REMOTE_USER_HOME:-/home/vscode}"
if [[ ! -d "${TARGET_HOME}" ]]; then
  TARGET_HOME="${HOME}"
fi

mkdir -p "${TARGET_HOME}/.gemini"
cat >"${TARGET_HOME}/.gemini/settings.json" <<'JSON'
{
  "mcpServers": {
    "genmedia-avtool": {
      "command": "avtool",
      "args": [],
      "transport": "stdio"
    }
  }
}
JSON

if [[ -n "${_REMOTE_USER:-}" ]] && id -u "${_REMOTE_USER}" >/dev/null 2>&1; then
  chown -R "${_REMOTE_USER}:${_REMOTE_USER}" "${TARGET_HOME}/.gemini"
fi

apt-get clean
rm -rf /var/lib/apt/lists/*

echo "Feature mcp-genmedia installed"
