#!/usr/bin/env bash
set -euo pipefail

# Gondolin + Claude Code - Simple Bash Wrapper
# This script launches an interactive shell with Claude Code available

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
IMAGE_DIR="${SCRIPT_DIR}/custom-gondolin-assets"

# Toggle between local gondolin installation and npx version
# Set USE_LOCAL_GONDOLIN=0 to use npx, otherwise uses ~/dev/gondolin (default)
if [[ "${USE_LOCAL_GONDOLIN:-1}" == "1" ]]; then
  GONDOLIN_CMD="node ${HOME}/dev/gondolin/host/dist/bin/gondolin.js"
else
  GONDOLIN_CMD="npx @earendil-works/gondolin"
fi

# Parse command line arguments
MOUNT_DIR=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --mount)
            MOUNT_DIR="$2"
            shift 2
            ;;
        *)
            echo "❌ Unknown argument: $1"
            echo "Usage: $0 --mount <directory>"
            exit 1
            ;;
    esac
done

# Validate mount directory is provided
if [[ -z "${MOUNT_DIR}" ]]; then
    echo "❌ Mount directory not specified"
    echo "Usage: $0 --mount <directory>"
    exit 1
fi

# Expand tilde to home directory if present
MOUNT_DIR="${MOUNT_DIR/#\~/$HOME}"

# Validate mount directory exists
if [[ ! -d "${MOUNT_DIR}" ]]; then
    echo "❌ Mount directory does not exist: ${MOUNT_DIR}"
    exit 1
fi

if [[ ! -d "${IMAGE_DIR}" ]]; then
    echo "❌ Custom image not found at: ${IMAGE_DIR}"
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🏗️  Gondolin + Claude Code"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📂 Mounting: ${MOUNT_DIR} -> /workspace"
echo "🤖 Claude Code: /usr/local/bin/claude"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Export environment variables for VM
export GONDOLIN_GUEST_DIR="${IMAGE_DIR}"

# Launch interactive shell in the workspace
cd "${MOUNT_DIR}"

# Build environment variable arguments
ENV_ARGS=()
if [[ -n "${CLAUDE_CODE_USE_BEDROCK:-}" ]]; then
  ENV_ARGS+=(--env "CLAUDE_CODE_USE_BEDROCK=${CLAUDE_CODE_USE_BEDROCK}")
fi

# Pass AWS environment variables to the VM
if [[ -n "${AWS_PROFILE:-}" ]]; then
  ENV_ARGS+=(--env "AWS_PROFILE=${AWS_PROFILE}")
fi
if [[ -n "${AWS_REGION:-}" ]]; then
  ENV_ARGS+=(--env "AWS_REGION=${AWS_REGION}")
fi
if [[ -n "${AWS_DEFAULT_REGION:-}" ]]; then
  ENV_ARGS+=(--env "AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}")
fi

# Pass Anthropic model configuration to the VM
if [[ -n "${ANTHROPIC_MODEL:-}" ]]; then
  ENV_ARGS+=(--env "ANTHROPIC_MODEL=${ANTHROPIC_MODEL}")
fi
if [[ -n "${ANTHROPIC_DEFAULT_SONNET_MODEL:-}" ]]; then
  ENV_ARGS+=(--env "ANTHROPIC_DEFAULT_SONNET_MODEL=${ANTHROPIC_DEFAULT_SONNET_MODEL}")
fi
if [[ -n "${ANTHROPIC_DEFAULT_HAIKU_MODEL:-}" ]]; then
  ENV_ARGS+=(--env "ANTHROPIC_DEFAULT_HAIKU_MODEL=${ANTHROPIC_DEFAULT_HAIKU_MODEL}")
fi
if [[ -n "${ANTHROPIC_DEFAULT_OPUS_MODEL:-}" ]]; then
  ENV_ARGS+=(--env "ANTHROPIC_DEFAULT_OPUS_MODEL=${ANTHROPIC_DEFAULT_OPUS_MODEL}")
fi
if [[ -n "${ANTHROPIC_SMALL_FAST_MODEL:-}" ]]; then
  ENV_ARGS+=(--env "ANTHROPIC_SMALL_FAST_MODEL=${ANTHROPIC_SMALL_FAST_MODEL}")
fi

exec ${GONDOLIN_CMD} bash \
  --mount-hostfs "${MOUNT_DIR}:/workspace" \
  --mount-hostfs "${HOME}/.aws:/root/.aws:ro" \
  --allow-host "api.anthropic.com" \
  --allow-host "platform.claude.com" \
  --allow-host "*.amazonaws.com" \
  --allow-host "bedrock-runtime.*.amazonaws.com" \
  --cwd /workspace \
  ${ENV_ARGS[@]+"${ENV_ARGS[@]}"}
