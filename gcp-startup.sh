#!/bin/bash
set -e

# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Enable IP forwarding (recommended for Tailscale)
echo 'net.ipv4.ip_forward = 1' | tee -a /etc/sysctl.d/99-tailscale.conf
echo 'net.ipv6.conf.all.forwarding = 1' | tee -a /etc/sysctl.d/99-tailscale.conf
sysctl -p /etc/sysctl.d/99-tailscale.conf

# Create max user FIRST so Tailscale can map the connection
if ! id "max" &>/dev/null; then
    useradd -m -s /bin/bash -G sudo max
    echo "max ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/max
fi

# Get the auth key from metadata
TS_AUTHKEY=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/attributes/tailscale-auth-key)

if [ -n "$TS_AUTHKEY" ]; then
  # Bring up Tailscale IMMEDIATELY so we can connect while the rest installs
  tailscale up --authkey="$TS_AUTHKEY" --ssh --hostname=gcp-dev-box --accept-dns=false --force-reauth
else
  echo "No Tailscale auth key found in metadata!"
fi

# 1. Install System Dependencies
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y \
    git \
    curl \
    build-essential \
    libssl-dev \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    wget \
    llvm \
    libncurses5-dev \
    libncursesw5-dev \
    xz-utils \
    tk-dev \
    libffi-dev \
    liblzma-dev \
    python3-openssl \
    ripgrep

# Install GitHub CLI
type -p curl >/dev/null || apt-get install curl -y
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
&& chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
&& apt-get update \
&& apt-get install gh -y

# Install zsh and fortune
apt-get install -y zsh fortune-mod

# 2. Install User Tools (mise, languages, AI tools)
# We run this as max to install into /home/max
sudo -u max bash << 'EOF'
# Install oh-my-zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Install mise
curl https://mise.run | sh
echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
echo 'eval "$(~/.local/bin/mise activate zsh)"' >> ~/.zshrc
export PATH="/home/max/.local/bin:$PATH"

# Install Python and Node.js
mise install python@3.12.7
mise install node@22.11.0
mise use -g python@3.12.7
mise use -g node@22.11.0

# Install uv (fast Python package installer)
curl -LsSf https://astral.sh/uv/install.sh | sh

# Install Bun (fast JavaScript runtime)
curl -fsSL https://bun.sh/install | bash

# Install AI Tools via npm (managed by mise)
mise exec -- npm install -g @sourcegraph/amp@latest @anthropic-ai/claude-code@latest @ast-grep/cli@latest @ast-grep/napi vercel

# Add npm global bin to PATH permanently
NPM_GLOBAL_BIN=$(mise exec -- npm config get prefix)/bin
echo "export PATH=\"$NPM_GLOBAL_BIN:\$PATH\"" >> ~/.bashrc

# Add uv and bun to PATH permanently
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
echo 'export PATH="$HOME/.bun/bin:$PATH"' >> ~/.bashrc

# Configure zsh with plugins and settings
cat > ~/.zshrc << 'ZSHEOF'
# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set theme
ZSH_THEME="robbyrussell"

# Which plugins would you like to load?
plugins=(git docker gcloud aws azure docker-compose)

source $ZSH/oh-my-zsh.sh

# User configuration
eval "$(~/.local/bin/mise activate zsh)"

# Add npm global bin to PATH
NPM_GLOBAL_BIN=$(mise exec -- npm config get prefix)/bin
export PATH="$NPM_GLOBAL_BIN:$PATH"

# Add uv and bun to PATH
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.bun/bin:$PATH"

# Add personal bin to PATH
export PATH="$HOME/bin:$PATH"

# Aliases
alias c="claude"
alias cds="claude --dangerously-skip-permissions --model claude-sonnet-4-20250514"
alias ccs="c --continue --dangerously-skip-permissions --model claude-sonnet-4-20250514"

# Run fortune on shell startup
fortune
ZSHEOF

# Change default shell to zsh
EOF

# Change max user's default shell to zsh
chsh -s /bin/zsh max

# 3. Create Workspace Directories and Setup .claude Config from Git Repo
mkdir -p /home/max/workspace

# Clone the sandbox repo to get .claude configuration
cd /tmp
git clone https://github.com/mkrueger12/sandbox.git

# Copy .claude directory (for CLAUDE.md and other config)
if [ -d "/tmp/sandbox/.claude" ]; then
    cp -r /tmp/sandbox/.claude /home/max/
    echo "Claude directory copied from GitHub repo"
else
    mkdir -p /home/max/.claude
    echo "Warning: No .claude directory found in repo"
fi

# Configure MCP servers in ~/.claude.json (the correct location)
cat > /home/max/.claude.json << 'CLAUDEJSONEOF'
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
CLAUDEJSONEOF
echo "MCP servers configured in ~/.claude.json"

rm -rf /tmp/sandbox

chown -R max:max /home/max/workspace /home/max/.claude /home/max/.claude.json

# 4. Configure GitHub Credentials
GITHUB_TOKEN=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/attributes/github-token 2>/dev/null)
if [ -n "$GITHUB_TOKEN" ]; then
    sudo -u max bash << EOF
# Configure git to use the token for HTTPS clones
git config --global credential.helper store
echo "https://oauth2:${GITHUB_TOKEN}@github.com" > /home/max/.git-credentials
chmod 600 /home/max/.git-credentials

# Set up gh CLI authentication
echo "${GITHUB_TOKEN}" | gh auth login --with-token

# Set basic git config
git config --global user.name "Max"
git config --global user.email "max@backlandlabs.io"
EOF
    echo "GitHub credentials configured"
else
    echo "No GitHub token found in metadata - skipping GitHub auth setup"
fi

# 5. Configure Claude Code Credentials
CLAUDE_OAUTH_TOKEN=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/attributes/claude-oauth-token 2>/dev/null)
if [ -n "$CLAUDE_OAUTH_TOKEN" ]; then
    sudo -u max bash << EOF
# Create Claude Code config file with OAuth token
mkdir -p /home/max/.claude
cat > /home/max/.claude/config.json << 'CONFIGEOF'
{
  "token": "${CLAUDE_OAUTH_TOKEN}"
}
CONFIGEOF
chmod 600 /home/max/.claude/config.json
EOF
    echo "Claude OAuth token configured"
else
    echo "No Claude OAuth token found in metadata - skipping OAuth token setup"
fi

echo "Startup script completed successfully."
