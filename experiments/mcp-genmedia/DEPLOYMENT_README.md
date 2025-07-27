# MCP Genmedia + Gemini CLI Deployment Guide

## Overview

This guide covers deploying the MCP Genmedia + Gemini CLI integration to Google Cloud Platform using containerized deployment with DevContainers, Docker, and Cloud Run.

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Developer     │    │   CI/CD         │    │   Production    │
│   Environment   │    │   Pipeline      │    │   Cloud Run     │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│ • DevContainer  │    │ • GitHub Actions│    │ • MCP Servers   │
│ • Local Docker  │    │ • Cloud Build   │    │ • Gemini CLI    │
│ • MCP Servers   │    │ • Terraform     │    │ • Health Checks │
│ • VS Code       │    │ • Security Scan │    │ • Auto-scaling  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Quick Start

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Google Cloud CLI](https://cloud.google.com/sdk/docs/install)
- [Node.js 18+](https://nodejs.org/)
- [Python 3.11+](https://www.python.org/)
- [Go 1.21+](https://golang.org/)
- [VS Code](https://code.visualstudio.com/) (recommended)

### 1. Initial Setup

```bash
# Clone and navigate to the project
cd vertex-ai-creative-studio/experiments/mcp-genmedia

# Run the setup script
./local-setup.sh

# Copy and configure environment
cp .env.example .env
# Edit .env with your project settings
```

### 2. Configure Google Cloud

```bash
# Authenticate with Google Cloud
gcloud auth login
gcloud auth application-default login

# Set your project
gcloud config set project YOUR_PROJECT_ID
```

### 3. Start Development Environment

```bash
# Option 1: Local development
./start-dev.sh

# Option 2: DevContainer (VS Code)
code .
# Reopen in container when prompted

# Option 3: Docker Compose
docker-compose -f docker-compose.dev.yml up
```

## Deployment Options

### Development Deployment

#### DevContainer Environment

The DevContainer provides a complete development environment with all dependencies pre-installed:

```bash
# Open in VS Code
code .
# Reopen in container

# All tools are available:
mcp-inspector    # Debug MCP servers
gcloud           # Google Cloud CLI
python3          # Python with Vertex AI SDK
node             # Node.js with MCP packages
go               # Go compiler
```

#### Local Docker Development

```bash
# Build and run locally
docker-compose -f docker-compose.dev.yml up

# Access services:
# - Main app: http://localhost:8080
# - Health check: http://localhost:8080/health
# - Redis: localhost:6379
# - PostgreSQL: localhost:5432
```

### Production Deployment

#### Option 1: Cloud Build (Recommended)

```bash
# Deploy using Cloud Build
./deploy-production.sh

# Commands available:
./deploy-production.sh deploy    # Full deployment
./deploy-production.sh rollback  # Rollback to previous version
./deploy-production.sh info      # Show deployment info
./deploy-production.sh cleanup   # Clean old revisions
```

#### Option 2: Terraform Infrastructure

```bash
# Initialize and deploy infrastructure
./deploy-terraform.sh deploy

# Commands available:
./deploy-terraform.sh init       # Initialize Terraform
./deploy-terraform.sh plan       # Generate execution plan
./deploy-terraform.sh apply      # Apply changes
./deploy-terraform.sh destroy    # Destroy infrastructure
./deploy-terraform.sh output     # Show outputs
```

#### Option 3: GitHub Actions CI/CD

1. **Configure Repository Secrets:**
   ```
   GCP_PROJECT_ID: your-project-id
   GCP_SA_KEY: {"type": "service_account", ...}
   ```

2. **Push to main branch:**
   ```bash
   git add .
   git commit -m "Deploy MCP Genmedia"
   git push origin main
   ```

3. **Monitor deployment:**
   - Check GitHub Actions tab
   - View logs in Google Cloud Console

## Configuration

### Environment Variables

Required variables for all environments:

```bash
# Google Cloud Configuration
PROJECT_ID=your-project-id              # GCP project ID
LOCATION=us-central1                     # GCP region
GENMEDIA_BUCKET=your-project-genmedia    # Storage bucket

# Optional: API Keys
BRAVE_API_KEY=your-brave-api-key         # Web search capability
```

### MCP Server Configuration

MCP servers are configured in `~/.config/mcp/config.json`:

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["@modelcontextprotocol/server-filesystem", "."]
    },
    "memory": {
      "command": "npx",
      "args": ["@modelcontextprotocol/server-memory"]
    },
    "brave-search": {
      "command": "npx",
      "args": ["@modelcontextprotocol/server-brave-search"],
      "env": {"BRAVE_API_KEY": ""}
    },
    "genmedia": {
      "command": "./bin/mcp-genmedia-server",
      "args": [],
      "env": {
        "PROJECT_ID": "",
        "LOCATION": "us-central1",
        "GENMEDIA_BUCKET": ""
      }
    }
  }
}
```

### Cloud Run Configuration

Production Cloud Run service configuration:

- **CPU:** 2 vCPU
- **Memory:** 2 GB
- **Timeout:** 900 seconds
- **Concurrency:** 10 requests
- **Auto-scaling:** 0-10 instances
- **Health checks:** `/health` endpoint

## Monitoring and Debugging

### Health Checks

The service provides comprehensive health monitoring:

```bash
# Check service health
curl https://your-service-url/health

# Response format:
{
  "status": "healthy",
  "timestamp": "2024-01-01T12:00:00Z",
  "services": {
    "filesystem": "running",
    "memory": "running",
    "brave": "running",
    "genmedia": "running"
  },
  "gcloud_auth": "authenticated"
}
```

### Logging

View application logs:

```bash
# Cloud Run logs
gcloud logs tail /projects/PROJECT_ID/logs/run.googleapis.com%2Fstdout

# Container logs (local)
docker logs mcp-genmedia

# Follow logs in real-time
gcloud logs tail /projects/PROJECT_ID/logs/run.googleapis.com%2Fstdout --follow
```

### Debugging MCP Servers

```bash
# Use MCP Inspector for debugging
mcp-inspector

# Test MCP connectivity
./test-mcp-connectivity.sh

# Manual server testing
npx @modelcontextprotocol/server-filesystem .
```

## Security

### Authentication

- **Google Cloud:** Service account with minimal required permissions
- **API Keys:** Stored in Secret Manager
- **Container:** Non-root user execution
- **Network:** HTTPS only, no public storage access

### Permissions

Required IAM roles:

```bash
# Cloud Build Service Account
roles/cloudbuild.builds.builder
roles/run.admin
roles/storage.admin
roles/secretmanager.secretAccessor
roles/iam.serviceAccountUser

# Cloud Run Service Account  
roles/aiplatform.user
roles/storage.objectAdmin
roles/secretmanager.secretAccessor
```

### Secrets Management

```bash
# Create secrets
gcloud secrets create brave-api-key --data-file=-

# Update secrets
echo "new-api-key" | gcloud secrets versions add brave-api-key --data-file=-

# View secret metadata
gcloud secrets describe brave-api-key
```

## Scaling and Performance

### Automatic Scaling

Cloud Run automatically scales based on:
- Request volume
- CPU utilization
- Memory usage
- Custom metrics

### Performance Tuning

```yaml
# Cloud Run resource limits
resources:
  limits:
    cpu: "2000m"      # 2 vCPU
    memory: "2Gi"     # 2 GB RAM

# Concurrency settings
annotations:
  run.googleapis.com/cpu-throttling: "false"
  autoscaling.knative.dev/minScale: "0"
  autoscaling.knative.dev/maxScale: "10"
```

### Cost Optimization

- **Cold starts:** Minimized with optimized container
- **Idle costs:** Zero with scale-to-zero
- **Resource usage:** Right-sized for workload
- **Storage:** Lifecycle policies for old media

## Troubleshooting

### Common Issues

1. **Service won't start:**
   ```bash
   # Check logs
   gcloud logs tail /projects/PROJECT_ID/logs/run.googleapis.com%2Fstderr
   
   # Verify environment variables
   gcloud run services describe mcp-genmedia --region=us-central1
   ```

2. **Authentication errors:**
   ```bash
   # Verify service account
   gcloud iam service-accounts list
   
   # Check permissions
   gcloud projects get-iam-policy PROJECT_ID
   ```

3. **MCP servers not responding:**
   ```bash
   # Test individual servers
   ./test-mcp-connectivity.sh
   
   # Check server logs
   docker logs mcp-genmedia
   ```

4. **Build failures:**
   ```bash
   # Check Cloud Build logs
   gcloud builds list --limit=5
   
   # View specific build
   gcloud builds log BUILD_ID
   ```

### Debug Commands

```bash
# Interactive container access
docker run -it --entrypoint bash gcr.io/PROJECT_ID/mcp-genmedia

# Local development with debug output
DEBUG=* ./start-dev.sh

# Test specific components
python3 test-gemini-mcp.py
./test-mcp-connectivity.sh

# Health check debugging
curl -v https://your-service-url/health
```

## Backup and Recovery

### State Backup

```bash
# Backup Terraform state
./deploy-terraform.sh backup

# Export Cloud Run configuration
gcloud run services describe mcp-genmedia \
  --region=us-central1 \
  --format=export > backup/cloudrun-config.yaml
```

### Disaster Recovery

```bash
# Restore from backup
gcloud run services replace backup/cloudrun-config.yaml

# Rollback deployment
./deploy-production.sh rollback

# Restore Terraform state
cp backup/terraform.tfstate.backup.TIMESTAMP deployment/terraform/terraform.tfstate
```

## Migration Guide

### From Local to Cloud

1. **Export local configuration:**
   ```bash
   cp ~/.config/mcp/config.json backup/
   cp .env backup/
   ```

2. **Deploy infrastructure:**
   ```bash
   ./deploy-terraform.sh deploy
   ```

3. **Deploy application:**
   ```bash
   ./deploy-production.sh deploy
   ```

### Between Environments

```bash
# Export from staging
gcloud run services describe mcp-genmedia --region=us-central1 --format=export > staging-config.yaml

# Import to production
gcloud run services replace staging-config.yaml --region=us-central1
```

## API Reference

### Health Endpoint

```http
GET /health
Content-Type: application/json

{
  "status": "healthy|degraded|unhealthy",
  "timestamp": "2024-01-01T12:00:00Z",
  "services": {
    "filesystem": "running|stopped|not_started",
    "memory": "running|stopped|not_started", 
    "brave": "running|stopped|not_started",
    "genmedia": "running|stopped|not_started"
  },
  "gcloud_auth": "authenticated|not_authenticated"
}
```

## Contributing

### Development Workflow

1. **Setup development environment:**
   ```bash
   ./local-setup.sh
   code .  # Open in VS Code + DevContainer
   ```

2. **Make changes and test:**
   ```bash
   ./run-tests.sh
   ./test-mcp-connectivity.sh
   ```

3. **Deploy to staging:**
   ```bash
   ./deploy-production.sh deploy
   ```

4. **Create pull request:**
   - CI/CD will run tests automatically
   - Deployment happens on merge to main

### Code Standards

- **Python:** Black formatting, type hints
- **Node.js:** ESLint + Prettier, TypeScript
- **Go:** gofmt, golint
- **Docker:** Multi-stage builds, non-root user

## Support

### Getting Help

1. **Documentation:** Check this README and inline comments
2. **Logs:** Review application and Cloud Build logs
3. **Community:** MCP GitHub discussions
4. **Issues:** Report bugs in the project repository

### Resources

- [MCP Documentation](https://github.com/modelcontextprotocol)
- [Google Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Vertex AI Documentation](https://cloud.google.com/vertex-ai/docs)
- [DevContainer Documentation](https://containers.dev/)

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.