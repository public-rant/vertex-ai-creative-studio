FROM mcr.microsoft.com/devcontainers/base:debian-12

ARG GO_VERSION=1.22.6

# Install system dependencies for Genmedia MCP development.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      ffmpeg \
      gettext-base \
      jq \
      python3-venv \
      python3-pip \
      shellcheck \
      ca-certificates \
      curl \
      git \
      unzip \
      wget \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 20.x.
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Go toolchain.
RUN wget -q https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz -O /tmp/go.tar.gz \
    && tar -C /usr/local -xzf /tmp/go.tar.gz \
    && rm -f /tmp/go.tar.gz

ENV GOPATH=/home/vscode/go
ENV PATH=/usr/local/go/bin:${GOPATH}/bin:${PATH}

# Keep script and config assets in the workspace-mounted repository.
WORKDIR /workspaces/vertex-ai-creative-studio/experiments/mcp-genmedia
