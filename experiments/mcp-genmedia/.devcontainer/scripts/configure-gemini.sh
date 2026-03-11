#!/usr/bin/env bash
set -euo pipefail

echo "Configuring Gemini CLI extension for MCP Genmedia..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_TEMPLATE="${SCRIPT_DIR}/../configs/gemini-extension.json"
EXTENSION_DIR="${HOME}/.gemini/extensions/google-genmedia-extension"

if [[ ! -f "${CONFIG_TEMPLATE}" ]]; then
  echo "Missing Gemini extension template: ${CONFIG_TEMPLATE}"
  exit 1
fi

sudo bash -c 'cat > /usr/local/bin/gemini << "EOL"
#!/usr/bin/env bash
exec npx https://github.com/google-gemini/gemini-cli "$@"
EOL'
sudo chmod +x /usr/local/bin/gemini

mkdir -p "${EXTENSION_DIR}"
envsubst '$GOPATH $PROJECT_ID $LOCATION $GENMEDIA_BUCKET' < "${CONFIG_TEMPLATE}" \
  > "${EXTENSION_DIR}/gemini-extension.json"

echo "Gemini extension configuration created at ${EXTENSION_DIR}/gemini-extension.json"
