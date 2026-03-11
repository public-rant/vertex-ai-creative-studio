# DevContainer verification notes

This file records local checks for the DevContainer implementation tracked from upstream issue #411.

## Static validation performed in this repository

Run from repo root:

```bash
jq . experiments/mcp-genmedia/.devcontainer/devcontainer.json
jq -r '.workspaceFolder' experiments/mcp-genmedia/.devcontainer/devcontainer.json
bash -n experiments/mcp-genmedia/.devcontainer/scripts/setup-mcp-servers.sh
bash -n experiments/mcp-genmedia/.devcontainer/scripts/configure-gemini.sh
shellcheck experiments/mcp-genmedia/.devcontainer/scripts/setup-mcp-servers.sh experiments/mcp-genmedia/.devcontainer/scripts/configure-gemini.sh
```

Expected outcomes:

- `jq` prints normalized JSON and exits 0.
- `bash -n` exits 0 for both scripts.
- `shellcheck` exits 0 for both scripts.

## Runtime verification (inside DevContainer)

After **Reopen in Container** completes:

```bash
which mcp-veo-go mcp-imagen-go mcp-chirp3-go mcp-lyria-go mcp-avtool-go
cat ~/.config/mcp/config.json | jq '.mcpServers | keys'
echo '{"jsonrpc":"2.0","method":"tools/list","id":1}' | mcp-imagen-go | jq '.result.tools | length'
```

Expected outcomes:

- `which` resolves all five binaries under `/home/vscode/go/bin`.
- MCP config includes utility servers and all five Genmedia Go servers.
- `tools/list` returns a positive tool count when project/auth env vars are configured.
