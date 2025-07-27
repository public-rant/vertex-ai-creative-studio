#!/bin/bash
set -e

echo "Setting up MCP servers..."

# Ensure we're in the right directory
cd /workspace

# Create MCP config directory if it doesn't exist
mkdir -p ~/.config/mcp

# Install Node.js dependencies for MCP servers
echo "Installing Node.js MCP server dependencies..."
npm install -g @modelcontextprotocol/server-filesystem
npm install -g @modelcontextprotocol/server-memory
npm install -g @modelcontextprotocol/server-brave-search

# Build Go MCP server if it exists
if [ -d "mcp-genmedia-go" ]; then
    echo "Building Go MCP Genmedia server..."
    cd mcp-genmedia-go
    go mod tidy
    go build -o ../bin/mcp-genmedia-server .
    cd ..
fi

# Create bin directory for executables
mkdir -p bin

# Create MCP configuration file
echo "Creating MCP configuration..."
cat > ~/.config/mcp/config.json << 'EOF'
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["@modelcontextprotocol/server-filesystem", "/workspace"]
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
    "genmedia": {
      "command": "/workspace/bin/mcp-genmedia-server",
      "args": [],
      "env": {
        "PROJECT_ID": "${PROJECT_ID}",
        "LOCATION": "${LOCATION}",
        "GENMEDIA_BUCKET": "${GENMEDIA_BUCKET}"
      }
    }
  }
}
EOF

# Make scripts executable
chmod +x bin/mcp-genmedia-server 2>/dev/null || true

# Set up Python virtual environment for additional tools
echo "Setting up Python environment..."
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip

# Install additional Python dependencies for Vertex AI
pip install google-cloud-aiplatform google-auth google-auth-oauthlib google-cloud-storage

echo "MCP servers setup complete!"
echo "Configuration created at ~/.config/mcp/config.json"
echo "To use MCP servers, make sure to set the following environment variables:"
echo "  - PROJECT_ID: Your Google Cloud project ID"
echo "  - LOCATION: Your preferred location (default: us-central1)"
echo "  - GENMEDIA_BUCKET: Your Cloud Storage bucket for media files"
echo "  - BRAVE_API_KEY: Your Brave Search API key (optional)"
