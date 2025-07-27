#!/bin/bash
set -e

echo "Configuring Gemini CLI for MCP Genmedia..."

# Create the `gemini` executable wrapper
sudo bash -c 'cat > /usr/local/bin/gemini << "EOL"
#!/bin/bash
exec npx https://github.com/google-gemini/gemini-cli "$@"
EOL'
sudo chmod +x /usr/local/bin/gemini
echo "✓ Gemini CLI wrapper created at /usr/local/bin/gemini."

# Create the Gemini CLI extensions directory
mkdir -p ~/.gemini/extensions/google-genmedia-extension/
echo "✓ Gemini extensions directory created."

# Substitute environment variables into the template and save the final config
# `envsubst` is used to replace shell variables in the JSON template.
# The list of variables needs to be explicitly provided to envsubst.
envsubst '$GOPATH $PROJECT_ID $LOCATION $GENMEDIA_BUCKET' < /home/vscode/.devcontainer/configs/gemini-extension.json \
  > ~/.gemini/extensions/google-genmedia-extension/gemini-extension.json

echo "✓ Gemini extension configuration created with dynamic values."

echo "Gemini CLI configuration complete!"
