# MCP Genmedia DevContainer feature

This local feature installs a baseline Genmedia MCP tooling stack for reviewers and contributors.

## Default profile

The default profile intentionally keeps the install minimal:

- `installAll=false`
- `installAvtool=true`
- `installGoogleCloudCli=false`
- `installNode=true`
- `installGeminiCli=true`

That gives a quick POC environment with:

- `avtool` command available
- Gemini CLI available
- `~/.gemini/settings.json` preconfigured with a `genmedia-avtool` MCP server entry

## Feature options

| Option | Default | Description |
|---|---:|---|
| `installAll` | `false` | Enables all optional installs. |
| `installAvtool` | `true` | Installs avtool placeholder command for MCP workflows. |
| `installGoogleCloudCli` | `false` | Installs `gcloud` CLI. |
| `installNode` | `true` | Ensures Node.js + npm is available. |
| `installGeminiCli` | `true` | Installs Gemini CLI globally with npm. |

## Testing

See [NOTES.md](./NOTES.md) for full reviewer and scenario test commands.
