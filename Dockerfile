FROM cgr.dev/chainguard/wolfi-base:latest

# Install system packages available in Wolfi repos
RUN apk update && apk add --no-cache \
    python-3 \
    py3-pip \
    nodejs \
    npm \
    git \
    curl \
    ripgrep \
    docker-cli \
    ca-certificates \
    wget \
    bash \
    openssh-client \
    unzip

# Install uv (fast Python package installer)
RUN mkdir -p /usr/local/bin && \
    curl -LsSf https://astral.sh/uv/install.sh | sh && \
    cp /root/.local/bin/uv /usr/local/bin/ && \
    cp /root/.local/bin/uvx /usr/local/bin/

# Install Bun (fast JavaScript runtime)
RUN curl -fsSL https://bun.sh/install | bash && \
    cp /root/.bun/bin/bun /usr/local/bin/

# Install GitHub CLI
RUN wget https://github.com/cli/cli/releases/download/v2.83.1/gh_2.83.1_linux_arm64.tar.gz && \
    tar -xzf gh_2.83.1_linux_arm64.tar.gz && \
    cp gh_2.83.1_linux_arm64/bin/gh /usr/local/bin/ && \
    rm -rf gh_2.83.1_linux_arm64*

# Install ast-grep
# Note: The archive contains two binaries: 'sg' (437KB, minimal) and 'ast-grep' (45MB, full)
# We must use the full 'ast-grep' binary, not 'sg', as 'sg' hangs in this environment
RUN wget https://github.com/ast-grep/ast-grep/releases/download/0.40.0/app-aarch64-unknown-linux-gnu.zip && \
    unzip app-aarch64-unknown-linux-gnu.zip && \
    chmod +x ast-grep && \
    mv ast-grep /usr/local/bin/ast-grep && \
    rm app-aarch64-unknown-linux-gnu.zip sg

# Install Tailscale
RUN wget https://pkgs.tailscale.com/stable/tailscale_1.90.8_arm64.tgz && \
    tar -xzf tailscale_1.90.8_arm64.tgz && \
    cp tailscale_1.90.8_arm64/tailscale /usr/local/bin/ && \
    cp tailscale_1.90.8_arm64/tailscaled /usr/local/bin/ && \
    rm -rf tailscale_1.90.8_arm64*

# Note: Claude Code and ampcode are interactive CLI tools typically run from host
# Uncomment if you need them:
# RUN curl -fsSL https://ampcode.com/install.sh | bash

# Create workspace directory
WORKDIR /workspace

# Setup a non-root user for development
RUN addgroup -g 1000 developer && \
    adduser -D -u 1000 -G developer developer && \
    chown -R developer:developer /workspace

# Configure Claude Code MCP servers and settings for the developer user
RUN mkdir -p /home/developer/.claude && \
    cat > /home/developer/.claude/.mcp.json <<'EOF' && \
    cat > /home/developer/.claude/settings.json <<'EOF2' && \
    chown -R developer:developer /home/developer/.claude
{
  "mcpServers": {
    "deepwiki": {
      "type": "http",
      "url": "https://mcp.deepwiki.com/mcp"
    },
    "linear-server": {
      "type": "http",
      "url": "https://mcp.linear.app/mcp"
    }
  }
}
EOF
{
  "env": {
    "CLAUDE_CODE_ENABLE_TELEMETRY": "0",
    "DISABLE_TELEMETRY": "1"
  },
  "includeCoAuthoredBy": false,
  "permissions": {
    "defaultMode": "bypassPermissions"
  }
}
EOF2

USER developer

CMD ["/bin/bash"]
