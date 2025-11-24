#!/bin/bash
set -e

# Configuration
INSTANCE_NAME="dev-box"
ZONE="us-west4-a"
MACHINE_TYPE="e2-standard-4"
IMAGE_FAMILY="debian-13"
IMAGE_PROJECT="debian-cloud"

# Check for required environment variables
if [ -z "$TS_AUTHKEY" ]; then
    echo "Error: TS_AUTHKEY environment variable is not set."
    echo "Please generate an auth key at https://login.tailscale.com/admin/settings/keys"
    echo "and run: export TS_AUTHKEY=tskey-auth-..."
    exit 1
fi

if [ -z "$GITHUB_TOKEN" ]; then
    echo "Warning: GITHUB_TOKEN environment variable is not set."
    echo "GitHub credentials will not be configured on the remote instance."
    echo "Generate a token at https://github.com/settings/tokens"
fi

if [ -z "$CLAUDE_OAUTH_TOKEN" ]; then
    echo "Warning: CLAUDE_OAUTH_TOKEN environment variable is not set."
    echo "Claude Code will not be configured on the remote instance."
    echo "Run 'claude-code auth status' locally to get your OAuth token"
fi

echo "Creating firewall rule for Tailscale UDP optimization (if not exists)..."
gcloud compute firewall-rules create tailscale-allow-udp \
    --allow udp:41641 \
    --target-tags tailscale-access \
    --description "Allow Tailscale UDP optimization" \
    2>/dev/null || echo "Firewall rule likely exists, skipping."

echo "Deploying $INSTANCE_NAME to $ZONE..."

# Build metadata string with optional tokens
METADATA="tailscale-auth-key=$TS_AUTHKEY"
[ -n "$GITHUB_TOKEN" ] && METADATA="$METADATA,github-token=$GITHUB_TOKEN"
[ -n "$CLAUDE_OAUTH_TOKEN" ] && METADATA="$METADATA,claude-oauth-token=$CLAUDE_OAUTH_TOKEN"

gcloud compute instances create "$INSTANCE_NAME" \
    --zone="$ZONE" \
    --machine-type="$MACHINE_TYPE" \
    --image-family="$IMAGE_FAMILY" \
    --image-project="$IMAGE_PROJECT" \
    --metadata-from-file=startup-script=./gcp-startup.sh \
    --metadata="$METADATA" \
    --tags=tailscale-access \
    --no-address

# Clean up old SSH host keys to avoid verification errors on redeployment
echo "Removing old SSH host keys for $INSTANCE_NAME..."
ssh-keygen -R "$INSTANCE_NAME" 2>/dev/null || true

echo "Deployment initiated."
echo "The instance is provisioned with a startup script that will install and authenticate Tailscale."
echo "Tailscale should connect almost immediately."
echo "Note: Development tools (Python, Node, etc.) will continue installing in the background for a few minutes."
echo ""
echo "Connect with:"
echo "  ssh max@gcp-dev-box"
echo ""
echo "To restrict access solely to Tailscale, ensure your GCP Firewall rules do not allow TCP:22 from 0.0.0.0/0 to tag 'tailscale-access'."
echo "By default, GCP's 'default-allow-ssh' rule might allow this."
echo "You can delete the default rule or create a higher priority deny rule."
