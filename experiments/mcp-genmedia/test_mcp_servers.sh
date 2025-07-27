#!/bin/bash

# Test script for MCP servers
source .env

echo "Testing MCP servers with PROJECT_ID=$PROJECT_ID"
echo

for server in mcp-imagen-go mcp-veo-go mcp-chirp3-go mcp-lyria-go mcp-avtool-go; do
    echo -n "Testing $server... "
    if echo '{"jsonrpc":"2.0","method":"tools/list","id":1}' | $HOME/go/bin/$server 2>/dev/null | grep -q '"jsonrpc"'; then
        echo "✓ OK"
    else
        echo "✗ FAILED"
    fi
done
