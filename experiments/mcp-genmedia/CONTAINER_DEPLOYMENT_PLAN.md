# Container-Based Deployment Plan for MCP Genmedia + Gemini CLI

## Overview

This plan outlines how to use DevContainers to create a reproducible, containerized environment for the MCP Genmedia servers and Gemini CLI, then deploy it to Google Cloud. This approach eliminates the need for manual setup scripts and ensures consistent environments across development and production.

## Architecture

```
┌─────────────────────────────┐
│   Local Development         │
│  ┌─────────────────────┐    │
│  │  DevContainer       │    │
│  │  - Node.js 20.x     │    │
│  │  - Go 1.22.x        │    │
│  │  - MCP Servers      │    │
│  │  - Gemini CLI       │    │
│  └─────────────────────┘    │
└─────────────────────────────┘
              ↓
        Docker Build
              ↓
┌─────────────────────────────┐
│   Google Cloud              │
│  ┌─────────────────────┐    │
│  │ Artifact Registry   │    │
│  │ (Container Image)   │    │
│  └─────────────────────┘    │
│            ↓                │
│  ┌─────────────────────┐    │
│  │ Compute Engine      │    │
│  │ Container-Optimized │    │
│  │ OS Instance         │    │
│  └─────────────────────┘    │
└─────────────────────────────┘
```

## Phase 1: Create DevContainer Configuration

### 1.1 Directory Structure
```
vertex-ai-creative-studio/experiments/mcp-genmedia/
├── .devcontainer/
│   ├── devcontainer.json
│   ├── Dockerfile
│   └── scripts/
│       ├── setup-mcp-servers.sh
│       └── configure-gemini.sh
├── docker/
│   ├── Dockerfile.production
│   └── entrypoint.sh
└── deployment/
    ├── cloudbuild.yaml
    └── terraform/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

### 1.2 DevContainer Specification (.devcontainer/devcontainer.json)
```json
{
  "name": "MCP Genmedia + Gemini CLI",
  "dockerFile": "Dockerfile",
  "features": {
    "ghcr.io/devcontainers/features/docker-in-docker:2": {},
    "ghcr.io/devcontainers/features/gcloud-cli:1": {}
  },
  "customizations": {
    "vscode": {
      "extensions": [
        "golang.go",
        "ms-azuretools.vscode-docker"
      ]
    }
  },
  "postCreateCommand": "/workspace/.devcontainer/scripts/setup-mcp-servers.sh",
  "remoteUser": "vscode",
  "mounts": [
    "source=${localEnv:HOME}/.config/gcloud,target=/home/vscode/.config/gcloud,type=bind,consistency=cached"
  ],
  "env": {
    "PROJECT_ID": "${localEnv:PROJECT_ID}",
    "LOCATION": "us-central1",
    "GENMEDIA_BUCKET": "${localEnv:PROJECT_ID}-mcp-genmedia"
  }
}
```

### 1.3 DevContainer Dockerfile (.devcontainer/Dockerfile)
```dockerfile
FROM mcr.microsoft.com/devcontainers/base:debian-11

# Install Node.js 20.x
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get update \
    && apt-get install -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Go 1.22.x
RUN wget https://golang.org/dl/go1.22.4.linux-amd64.tar.gz \
    && tar -C /usr/local -xzf go1.22.4.linux-amd64.tar.gz \
    && rm go1.22.4.linux-amd64.tar.gz

# Set Go environment
ENV PATH="/usr/local/go/bin:${PATH}"
ENV GOPATH="/home/vscode/go"
ENV PATH="${GOPATH}/bin:${PATH}"

# Install additional tools
RUN apt-get update \
    && apt-get install -y git curl wget jq \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create workspace directory
WORKDIR /workspace

# Copy setup scripts
COPY scripts/ /workspace/.devcontainer/scripts/
RUN chmod +x /workspace/.devcontainer/scripts/*.sh
```

### 1.4 MCP Server Setup Script (.devcontainer/scripts/setup-mcp-servers.sh)
```bash
#!/bin/bash
set -e

echo "Setting up MCP Genmedia servers..."

# Clone repository if not already present
if [ ! -d "/workspace/vertex-ai-creative-studio" ]; then
    git clone https://github.com/GoogleCloudPlatform/vertex-ai-creative-studio.git /workspace/vertex-ai-creative-studio
fi

# Install MCP servers
cd /workspace/vertex-ai-creative-studio/experiments/mcp-genmedia/mcp-genmedia-go
go work sync
go install ./mcp-avtool-go ./mcp-chirp3-go ./mcp-imagen-go ./mcp-lyria-go ./mcp-veo-go

# Configure Gemini CLI
/workspace/.devcontainer/scripts/configure-gemini.sh

echo "MCP Genmedia setup complete!"
```

### 1.5 Gemini Configuration Script (.devcontainer/scripts/configure-gemini.sh)
```bash
#!/bin/bash
set -e

# Create Gemini wrapper
sudo bash -c 'cat > /usr/local/bin/gemini << "EOL"
#!/bin/bash
exec npx https://github.com/google-gemini/gemini-cli "$@"
EOL'
sudo chmod +x /usr/local/bin/gemini

# Create Gemini extension directory
mkdir -p ~/.gemini/extensions/google-genmedia-extension/

# Generate extension configuration
cat > ~/.gemini/extensions/google-genmedia-extension/gemini-extension.json << EOF
{
  "name": "google-genmedia-extension",
  "version": "1.0.0",
  "mcpServers": {
    "veo": {
      "command": "${GOPATH}/bin/mcp-veo-go",
      "env": {
        "MCP_REQUEST_MAX_TOTAL_TIMEOUT": "240000",
        "MCP_SERVER_REQUEST_TIMEOUT": "30000",
        "GENMEDIA_BUCKET": "${GENMEDIA_BUCKET}",
        "PROJECT_ID": "${PROJECT_ID}",
        "LOCATION": "${LOCATION}"
      }
    },
    "imagen": {
      "command": "${GOPATH}/bin/mcp-imagen-go",
      "env": {
        "MCP_SERVER_REQUEST_TIMEOUT": "55000",
        "GENMEDIA_BUCKET": "${GENMEDIA_BUCKET}",
        "PROJECT_ID": "${PROJECT_ID}",
        "LOCATION": "${LOCATION}"
      }
    },
    "chirp3-hd": {
      "command": "${GOPATH}/bin/mcp-chirp3-go",
      "env": {
        "MCP_SERVER_REQUEST_TIMEOUT": "55000",
        "GENMEDIA_BUCKET": "${GENMEDIA_BUCKET}",
        "PROJECT_ID": "${PROJECT_ID}",
        "LOCATION": "${LOCATION}"
      }
    },
    "lyria": {
      "command": "${GOPATH}/bin/mcp-lyria-go",
      "env": {
        "GENMEDIA_BUCKET": "${GENMEDIA_BUCKET}",
        "PROJECT_ID": "${PROJECT_ID}",
        "MCP_SERVER_REQUEST_TIMEOUT": "55000",
        "LOCATION": "${LOCATION}"
      }
    },
    "avtool": {
      "command": "${GOPATH}/bin/mcp-avtool-go",
      "env": {
        "PROJECT_ID": "${PROJECT_ID}",
        "MCP_SERVER_REQUEST_TIMEOUT": "55000",
        "LOCATION": "${LOCATION}"
      }
    }
  }
}
EOF
```

## Phase 2: Production Docker Image

### 2.1 Production Dockerfile (docker/Dockerfile.production)
```dockerfile
FROM debian:11-slim

# Install runtime dependencies
RUN apt-get update \
    && apt-get install -y \
        ca-certificates \
        curl \
        git \
        ffmpeg \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 20.x
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Go 1.22.x
RUN wget https://golang.org/dl/go1.22.4.linux-amd64.tar.gz \
    && tar -C /usr/local -xzf go1.22.4.linux-amd64.tar.gz \
    && rm go1.22.4.linux-amd64.tar.gz

# Set environment
ENV PATH="/usr/local/go/bin:${PATH}"
ENV GOPATH="/root/go"
ENV PATH="${GOPATH}/bin:${PATH}"

# Clone and build MCP servers
WORKDIR /app
RUN git clone https://github.com/GoogleCloudPlatform/vertex-ai-creative-studio.git \
    && cd vertex-ai-creative-studio/experiments/mcp-genmedia/mcp-genmedia-go \
    && go work sync \
    && go install ./mcp-avtool-go ./mcp-chirp3-go ./mcp-imagen-go ./mcp-lyria-go ./mcp-veo-go

# Create Gemini CLI wrapper
RUN echo '#!/bin/bash\nexec npx https://github.com/google-gemini/gemini-cli "$@"' > /usr/local/bin/gemini \
    && chmod +x /usr/local/bin/gemini

# Copy entrypoint script
COPY entrypoint.sh /app/
RUN chmod +x /app/entrypoint.sh

# Create non-root user
RUN useradd -m -s /bin/bash gemini
USER gemini
WORKDIR /home/gemini

# Configure Gemini extension
COPY --chown=gemini:gemini configure-gemini.sh /tmp/
RUN /tmp/configure-gemini.sh && rm /tmp/configure-gemini.sh

ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["gemini"]
```

### 2.2 Entrypoint Script (docker/entrypoint.sh)
```bash
#!/bin/bash
set -e

# Ensure environment variables are set
if [ -z "$PROJECT_ID" ]; then
    echo "ERROR: PROJECT_ID environment variable is not set"
    exit 1
fi

# Set default values
export LOCATION="${LOCATION:-us-central1}"
export GENMEDIA_BUCKET="${GENMEDIA_BUCKET:-${PROJECT_ID}-mcp-genmedia}"

# Create/verify GCS bucket if gcloud is available
if command -v gcloud &> /dev/null; then
    if ! gsutil ls "gs://${GENMEDIA_BUCKET}" &>/dev/null; then
        echo "Creating GCS bucket: gs://${GENMEDIA_BUCKET}"
        gsutil mb -p "${PROJECT_ID}" -c standard -l "${LOCATION}" "gs://${GENMEDIA_BUCKET}"
    fi
fi

# Execute command
exec "$@"
```

## Phase 3: Deployment Configuration

### 3.1 Cloud Build Configuration (deployment/cloudbuild.yaml)
```yaml
steps:
  # Build the production image
  - name: 'gcr.io/cloud-builders/docker'
    args: 
      - 'build'
      - '-t'
      - '${_REGION}-docker.pkg.dev/${PROJECT_ID}/mcp-genmedia/mcp-genmedia-gemini:${SHORT_SHA}'
      - '-t'
      - '${_REGION}-docker.pkg.dev/${PROJECT_ID}/mcp-genmedia/mcp-genmedia-gemini:latest'
      - '-f'
      - 'docker/Dockerfile.production'
      - '.'

  # Push to Artifact Registry
  - name: 'gcr.io/cloud-builders/docker'
    args: 
      - 'push'
      - '--all-tags'
      - '${_REGION}-docker.pkg.dev/${PROJECT_ID}/mcp-genmedia/mcp-genmedia-gemini'

  # Deploy to Compute Engine
  - name: 'gcr.io/google.com/cloudsdktool/cloud-sdk'
    entrypoint: 'gcloud'
    args:
      - 'compute'
      - 'instances'
      - 'create-with-container'
      - 'mcp-genmedia-instance'
      - '--zone=${_ZONE}'
      - '--container-image=${_REGION}-docker.pkg.dev/${PROJECT_ID}/mcp-genmedia/mcp-genmedia-gemini:${SHORT_SHA}'
      - '--machine-type=e2-medium'
      - '--boot-disk-size=20GB'
      - '--container-env=PROJECT_ID=${PROJECT_ID},LOCATION=${_REGION},GENMEDIA_BUCKET=${PROJECT_ID}-mcp-genmedia'
      - '--scopes=https://www.googleapis.com/auth/cloud-platform'
      - '--tags=http-server,https-server'

substitutions:
  _REGION: us-central1
  _ZONE: us-central1-a

options:
  logging: CLOUD_LOGGING_ONLY
```

### 3.2 Terraform Configuration (deployment/terraform/main.tf)
```hcl
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "us-central1-a"
}

# Artifact Registry for container images
resource "google_artifact_registry_repository" "mcp_genmedia" {
  location      = var.region
  repository_id = "mcp-genmedia"
  description   = "MCP Genmedia container images"
  format        = "DOCKER"
}

# GCS bucket for media assets
resource "google_storage_bucket" "genmedia" {
  name          = "${var.project_id}-mcp-genmedia"
  location      = var.region
  force_destroy = true
}

# Service account for the instance
resource "google_service_account" "mcp_genmedia" {
  account_id   = "mcp-genmedia-sa"
  display_name = "MCP Genmedia Service Account"
}

# IAM roles for the service account
resource "google_project_iam_member" "storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.mcp_genmedia.email}"
}

resource "google_project_iam_member" "vertex_ai_user" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.mcp_genmedia.email}"
}

# Compute instance with container
resource "google_compute_instance" "mcp_genmedia" {
  name         = "mcp-genmedia-instance"
  machine_type = "e2-medium"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "cos-cloud/cos-stable"
      size  = 20
    }
  }

  network_interface {
    network = "default"
    access_config {
      // Ephemeral public IP
    }
  }

  metadata = {
    gce-container-declaration = yamlencode({
      spec = {
        containers = [{
          name  = "mcp-genmedia"
          image = "${var.region}-docker.pkg.dev/${var.project_id}/mcp-genmedia/mcp-genmedia-gemini:latest"
          env = [
            {
              name  = "PROJECT_ID"
              value = var.project_id
            },
            {
              name  = "LOCATION"
              value = var.region
            },
            {
              name  = "GENMEDIA_BUCKET"
              value = google_storage_bucket.genmedia.name
            }
          ]
          stdin = true
          tty   = true
        }]
        restartPolicy = "Always"
      }
    })
    enable-oslogin = "TRUE"
  }

  service_account {
    email  = google_service_account.mcp_genmedia.email
    scopes = ["cloud-platform"]
  }

  tags = ["http-server", "https-server"]
}
```

## Phase 4: Local Development Workflow

### 4.1 Initial Setup
```bash
# Clone the repository
git clone https://github.com/GoogleCloudPlatform/vertex-ai-creative-studio.git
cd vertex-ai-creative-studio/experiments/mcp-genmedia

# Set environment variables
export PROJECT_ID="your-project-id"

# Open in VS Code with DevContainer
code .
# Then: "Reopen in Container" when prompted
```

### 4.2 Development Commands
```bash
# Inside the DevContainer

# Test MCP servers
echo '{"jsonrpc":"2.0","method":"tools/list","id":1}' | mcp-imagen-go

# Run Gemini CLI
gemini

# Use MCP servers in Gemini
/mcp
```

## Phase 5: Production Deployment Workflow

### 5.1 Using Cloud Build
```bash
# Enable required APIs
gcloud services enable \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  compute.googleapis.com

# Create Artifact Registry repository
gcloud artifacts repositories create mcp-genmedia \
  --repository-format=docker \
  --location=us-central1

# Submit build
gcloud builds submit \
  --config=deployment/cloudbuild.yaml \
  --substitutions=_REGION=us-central1,_ZONE=us-central1-a
```

### 5.2 Using Terraform
```bash
cd deployment/terraform

# Initialize Terraform
terraform init

# Plan deployment
terraform plan -var="project_id=${PROJECT_ID}"

# Apply deployment
terraform apply -var="project_id=${PROJECT_ID}"
```

### 5.3 Accessing the Deployed Instance
```bash
# SSH into the container
gcloud compute ssh mcp-genmedia-instance \
  --zone=us-central1-a \
  --container

# Or use OS Login
gcloud compute ssh mcp-genmedia-instance \
  --zone=us-central1-a
docker exec -it $(docker ps -q) /bin/bash
```

## Phase 6: CI/CD Integration

### 6.1 GitHub Actions Workflow (.github/workflows/deploy.yml)
```yaml
name: Deploy MCP Genmedia

on:
  push:
    branches: [main]
    paths:
      - 'experiments/mcp-genmedia/**'

env:
  PROJECT_ID: ${{ secrets.GCP_PROJECT_ID }}
  REGION: us-central1

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - uses: google-github-actions/auth@v1
      with:
        credentials_json: ${{ secrets.GCP_SA_KEY }}
    
    - uses: google-github-actions/setup-gcloud@v1
    
    - name: Configure Docker
      run: gcloud auth configure-docker ${REGION}-docker.pkg.dev
    
    - name: Build and Deploy
      run: |
        cd experiments/mcp-genmedia
        gcloud builds submit \
          --config=deployment/cloudbuild.yaml \
          --substitutions=_REGION=${REGION}
```

## Benefits of This Approach

1. **Reproducibility**: The same container runs locally and in production
2. **Version Control**: All configuration is tracked in Git
3. **Fast Deployment**: Pre-built images deploy in seconds
4. **Easy Updates**: Change code, rebuild, redeploy
5. **Cost Efficiency**: Container-Optimized OS uses fewer resources
6. **Security**: Minimal attack surface, defined service account permissions
7. **Scalability**: Easy to deploy multiple instances or use Cloud Run

## Next Steps

1. Create the directory structure and files outlined above
2. Test the DevContainer locally
3. Build and test the production image
4. Deploy using either Cloud Build or Terraform
5. Set up CI/CD for automated deployments
6. Consider adding:
   - Health checks
   - Monitoring and logging
   - Auto-scaling policies
   - Load balancing for multiple instances

This containerized approach provides a much more robust and maintainable solution than manual VM setup scripts.