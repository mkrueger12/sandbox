# GCP Dev Box

A hardened, polyglot remote development environment deployable to Google Cloud Platform (GCP) Compute Engine with Tailscale network access.

## Features

- **Platform**: GCP Compute Engine (Ubuntu 22.04 LTS)
- **Security**: Tailscale-only access
- **Development Tools**: 
  - **mise**: Version manager
  - **Languages**: Python 3.12.7, Node.js 22.11.0
  - **Tools**: git, gh, ripgrep, build essentials
- **AI Tools**: AMP Code, Claude Code, ast-grep

## Prerequisites

1. **GCP Account** & **Project**
2. **gcloud CLI** installed & authenticated
3. **Tailscale Account**

## Deployment

1. **Get Tailscale Auth Key**: https://login.tailscale.com/admin/settings/keys (Generate Reusable key)

2. **Set up credentials** (optional but recommended):
   ```bash
   # Required
   export TS_AUTHKEY="tskey-auth-..."

   # Optional: GitHub authentication
   export GITHUB_TOKEN="ghp_..."  # Generate at https://github.com/settings/tokens

   # Optional: Claude OAuth token
   export CLAUDE_OAUTH_TOKEN="..."  # Get via 'claude-code auth status' or from ~/.claude/config.json
   ```

   The startup script will automatically configure:
   - **GitHub**: git credentials for HTTPS clones, gh CLI authentication, and basic git config
   - **Claude Code**: OAuth token in config file

3. **Deploy**:
   ```bash
   ./deploy-gcp.sh
   ```
   This script will:
   - Create a firewall rule (`tailscale-allow-udp`) for UDP:41641 to allow direct Tailscale connections.
   - Create the VM instance and install Tailscale.
   - Configure Tailscale with `--accept-dns=false` to preserve GCP internal DNS.
   - Configure GitHub and Claude Code credentials if provided.

4. **Connect**:
   ```bash
   ssh max@gcp-dev-box
   ```

## Files

- `deploy-gcp.sh`: Creates the VM instance.
- `gcp-startup.sh`: Installs software on first boot.
- `.mise.toml`: Tool version definitions.

## Customization

Edit `deploy-gcp.sh` for VM size/zone.
Edit `gcp-startup.sh` for installed software.
