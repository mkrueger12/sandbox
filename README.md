# GCP Dev Box

A containerized, polyglot remote development environment deployable to Google Cloud Platform (GCP) Compute Engine with Tailscale network access.

## Features

- **Platform**: GCP Compute Engine with Container-Optimized OS
- **Container Base**: Chainguard Wolfi (minimal, security-hardened Linux)
- **Security**: Tailscale-only access
- **Development Tools**:
  - **Languages**: Python 3.12, Node.js, Bun
  - **Package Managers**: uv (Python), npm, Bun
  - **Tools**: Git, GitHub CLI, Docker CLI, ripgrep, ast-grep
  - **Network**: Tailscale
- **AI Tools**: AMP Code, Claude Code

## Architecture

The deployment uses a Docker container running on Container-Optimized OS:
- Base image: `cgr.dev/chainguard/wolfi-base:latest`
- Container runs with `--privileged` and `--network host` for Tailscale
- Persistent storage: `/home/developer` on host mapped to `/workspace` in container
- Auto-restart: systemd service ensures container restarts on failure

## Prerequisites

1. **GCP Account** & **Project**
2. **gcloud CLI** installed & authenticated
3. **Docker** installed locally (for building the image)
4. **Tailscale Account**

## Deployment

1. **Configure credentials** in `.env` file:
   ```bash
   # Create .env file (already in .gitignore)
   cat > .env << 'EOF'
   TS_AUTHKEY=tskey-auth-...
   GITHUB_TOKEN=ghp_...
   CLAUDE_OAUTH_TOKEN=sk-ant-oat01-...
   EOF
   ```

   Get your credentials:
   - **Tailscale Auth Key**: https://login.tailscale.com/admin/settings/keys (Generate Reusable key)
   - **GitHub Token**: https://github.com/settings/tokens
   - **Claude OAuth Token**: Run `claude-code auth status` or check `~/.claude/config.json`

2. **Deploy**:
   ```bash
   ./deploy-gcp.sh
   ```

   This script will:
   - Build the Docker image from your Dockerfile
   - Push it to Google Artifact Registry
   - Create/recreate the VM with Container-Optimized OS
   - Configure the container to start automatically with systemd
   - Set up Tailscale for secure access

3. **Monitor deployment**:
   ```bash
   # Check serial output for boot progress
   ./gcp-manage.sh serial

   # View container logs
   ./gcp-manage.sh logs

   # Check status
   ./gcp-manage.sh status
   ```

4. **Connect**:
   ```bash
   # Via Tailscale (once connected)
   ssh developer@gcp-dev-box

   # Or use the management script
   ./gcp-manage.sh connect
   ```

## Management

Use `gcp-manage.sh` for common operations:

```bash
./gcp-manage.sh status    # Show instance and container status
./gcp-manage.sh logs      # View container logs (follows)
./gcp-manage.sh restart   # Restart the container
./gcp-manage.sh ssh       # SSH into the VM host (not the container)
./gcp-manage.sh connect   # SSH into the running container
./gcp-manage.sh stop      # Stop the instance
./gcp-manage.sh start     # Start the instance
./gcp-manage.sh delete    # Delete the instance
./gcp-manage.sh serial    # View serial port output (for debugging)
```

## Files

- `Dockerfile`: Container image definition (Wolfi-based)
- `deploy-gcp.sh`: Builds image, pushes to registry, creates VM
- `gcp-manage.sh`: Helper script for managing the deployment
- `gcp-startup.sh`: Legacy startup script (not used with Container-Optimized OS)
- `.env`: Credentials (in .gitignore - create locally)

## Customization

- **VM Configuration**: Edit variables at the top of `deploy-gcp.sh`:
  - `INSTANCE_NAME`: VM name (default: gcp-dev-box)
  - `ZONE`: GCP zone (default: us-west4-a)
  - `MACHINE_TYPE`: VM size (default: e2-medium)

- **Container Configuration**: Edit `Dockerfile` to add/remove tools

- **Development Environment**: Copy `.claude/` directory contents to customize Claude Code settings

## Troubleshooting

### Container not starting
```bash
# View system logs
./gcp-manage.sh serial

# Check Docker on the host
./gcp-manage.sh ssh
docker ps -a
journalctl -u dev-container.service -f
```

### Tailscale not connecting
```bash
# Check container logs
./gcp-manage.sh logs

# Manually check Tailscale status
./gcp-manage.sh connect
tailscale status
```

### Image push fails
```bash
# Re-authenticate Docker
gcloud auth configure-docker us-west4-docker.pkg.dev
```

## Cost Optimization

- Default machine type is `e2-medium` (1 vCPU, 4GB RAM)
- Stop the instance when not in use: `./gcp-manage.sh stop`
- Delete when done: `./gcp-manage.sh delete`
