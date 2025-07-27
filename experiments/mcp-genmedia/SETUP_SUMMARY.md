# MCP Genmedia Setup Summary

## ✅ Setup Complete!

Your MCP Servers for Google Cloud Genmedia APIs have been successfully installed and configured.

## Installation Summary

### 1. **MCP Servers Installed**
All five MCP servers have been installed to `/Users/rant/go/bin/`:
- `mcp-imagen-go` - Image generation with Imagen 3/4
- `mcp-veo-go` - Video generation with Veo 2
- `mcp-chirp3-go` - Text-to-speech with Chirp 3 HD
- `mcp-lyria-go` - Music generation with Lyria
- `mcp-avtool-go` - Audio/video compositing and manipulation

### 2. **Environment Configuration**
- **Google Cloud Project**: `recopy-trial-unpopular`
- **GCS Bucket**: `recopy-trial-unpopular-mcp-genmedia`
- **Location**: `us-central1`
- **Configuration File**: `.env` (created in this directory)

### 3. **Authentication**
- ✅ Google Application Default Credentials are configured
- ✅ Access to Google Cloud APIs is set up

### 4. **PATH Configuration**
- Added Go binary directory to your shell configuration (`~/.bash_profile`)
- **Important**: You need to restart your shell or run:
  ```bash
  source ~/.bash_profile
  ```

## Quick Start Guide

### 1. Source the Environment
Before using any MCP server, source the environment variables:
```bash
cd experiments/mcp-genmedia
source .env
```

### 2. Test the Servers
Run the test script to verify all servers are working:
```bash
./test_mcp_servers.sh
```

### 3. Run a Server

#### STDIO Mode (default)
```bash
~/go/bin/mcp-imagen-go
```

#### HTTP Mode (for web clients)
```bash
~/go/bin/mcp-imagen-go --transport http
```

### 4. Try the Demo
Explore the capabilities with the demo script:
```bash
./demo_mcp_usage.sh
```

## Available Files

1. **`.env`** - Environment configuration file with your project settings
2. **`test_mcp_servers.sh`** - Test script to verify server installations
3. **`demo_mcp_usage.sh`** - Demo script showing how to use each server
4. **`mcp-config.json`** - MCP client configuration file for integrations
5. **`setup_environment.sh`** - Setup script (already run)

## Using with MCP Clients

### For Claude Desktop, Cline, or other MCP-compatible clients:
Use the `mcp-config.json` file which contains the full configuration for all servers with your project settings.

### For custom integrations:
Reference the sample agents in the `sample-agents/` directory:
- ADK (Agent Development Kit)
- Firebase Genkit
- geminicli

## Common Commands

### Generate an image:
```bash
echo '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"imagen_t2i","arguments":{"prompt":"A futuristic city skyline"}},"id":1}' | ~/go/bin/mcp-imagen-go
```

### List available tools:
```bash
echo '{"jsonrpc":"2.0","method":"tools/list","id":1}' | ~/go/bin/mcp-imagen-go
```

### Start HTTP server:
```bash
~/go/bin/mcp-imagen-go --transport http --port 8080
```

## Troubleshooting

### "command not found" error
Make sure to either:
1. Use the full path: `~/go/bin/mcp-imagen-go`
2. Or add Go bin to PATH and restart your shell:
   ```bash
   source ~/.bash_profile
   ```

### Authentication errors
Run:
```bash
gcloud auth application-default login
```

### Permission errors with GCS bucket
Grant yourself access:
```bash
gcloud storage buckets add-iam-policy-binding gs://recopy-trial-unpopular-mcp-genmedia \
  --member=user:YOUR_EMAIL \
  --role=roles/storage.objectUser
```

## Next Steps

1. **Explore the APIs**: Try different prompts and parameters with each server
2. **Build integrations**: Use the MCP servers in your AI applications
3. **Check the samples**: Look at the `sample-agents/` directory for integration examples
4. **Read the docs**: See the main README.md and Go implementations README for detailed information

## Resources

- [Google Cloud Vertex AI Documentation](https://cloud.google.com/vertex-ai/docs)
- [Model Context Protocol (MCP)](https://modelcontextprotocol.io/)
- [Project Repository](https://github.com/GoogleCloudPlatform/vertex-ai-creative-studio)

Happy creating with Google Cloud's generative media APIs! 🎨🎵🎬