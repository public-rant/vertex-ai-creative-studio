FROM mcr.microsoft.com/devcontainers/base:debian-11

# --- Install Node.js 20.x and npm ---
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get update \
    && apt-get install -y nodejs npm \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# --- Install Go 1.22.x ---
RUN wget https://golang.org/dl/go1.22.4.linux-amd64.tar.gz -O /tmp/go.tar.gz \
    && sudo tar -C /usr/local -xzf /tmp/go.tar.gz \
    && rm /tmp/go.tar.gz

# --- Set Go environment variables for the 'vscode' user ---
ENV PATH="/usr/local/go/bin:${PATH}"
ENV GOPATH="/home/vscode/go"
ENV PATH="${GOPATH}/bin:${PATH}"

# --- Install additional system tools ---
RUN apt-get update \
    && apt-get install -y git curl wget jq gettext-base \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# --- Clone and Build MCP Servers ---
WORKDIR /tmp/build
RUN git clone https://github.com/GoogleCloudPlatform/vertex-ai-creative-studio.git \
    && cd vertex-ai-creative-studio/experiments/mcp-genmedia/mcp-genmedia-go \
    && go work sync \
    && go install ./mcp-avtool-go ./mcp-chirp3-go ./mcp-imagen-go ./mcp-lyria-go ./mcp-veo-go \
    && rm -rf /tmp/build

# Ensure the workspace directory exists for the mounted project code
WORKDIR /workspace

# Copy scripts directory
COPY scripts/ /home/vscode/.devcontainer/scripts/
RUN chmod +x /home/vscode/.devcontainer/scripts/*.sh

# Copy static configuration files
COPY configs/ /home/vscode/.devcontainer/configs/

USER vscode
