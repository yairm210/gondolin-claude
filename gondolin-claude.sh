#!/usr/bin/env bash
set -euo pipefail

# Gondolin + Claude Code - Simple Bash Wrapper
# This script launches an interactive shell with Claude Code available

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
IMAGE_DIR="${SCRIPT_DIR}/custom-gondolin-assets"
ANALYTICS_DIR="${HOME}/dev/analytics"

if [[ ! -d "${IMAGE_DIR}" ]]; then
    echo "❌ Custom image not found at: ${IMAGE_DIR}"
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🏗️  Gondolin + Claude Code"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📂 Mounting: ${ANALYTICS_DIR} -> /workspace"
echo "🤖 Claude Code: /usr/local/bin/claude"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Export environment variables for VM
export GONDOLIN_GUEST_DIR="${IMAGE_DIR}"

# Launch interactive shell with mounts (uses login shell to source /etc/profile)
exec npx @earendil-works/gondolin exec \
  --mount-hostfs "${ANALYTICS_DIR}:/workspace" \
  --mount-hostfs "${HOME}/.aws:/root/.aws:ro" \
  --allow-host "api.anthropic.com" \
  --allow-host "platform.claude.com" \
  --allow-host "*.amazonaws.com" \
  --allow-host "bedrock-runtime.*.amazonaws.com" \
  -- /bin/bash -l
