#!/usr/bin/env bash
set -euo pipefail

# Gondolin + Claude Code - General Wrapper
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
USE_AWS=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --mount)
            MOUNT_DIR="$2"
            shift 2
            ;;
        --aws)
            USE_AWS=true
            shift
            ;;
        *)
            echo "❌ Unknown argument: $1"
            echo "Usage: $0 --mount <directory> [--aws]"
            exit 1
            ;;
    esac
done

# Validate mount directory is provided
if [[ -z "${MOUNT_DIR}" ]]; then
    echo "❌ Mount directory not specified"
    echo "Usage: $0 --mount <directory> [--aws]"
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

# Pass CLAUDE_CODE_* environment variables (except CLAUDE_CODE_USE_BEDROCK which is controlled by --aws)
for var in $(compgen -e | grep "^CLAUDE_CODE_" || true); do
  if [[ "${var}" != "CLAUDE_CODE_USE_BEDROCK" ]]; then
    ENV_ARGS+=(--env "${var}=${!var}")
  fi
done

# If --aws flag is set, enable Bedrock and pass AWS/Anthropic environment variables
if [[ "${USE_AWS}" == "true" ]]; then
  # Set Bedrock flag
  ENV_ARGS+=(--env "CLAUDE_CODE_USE_BEDROCK=1")

  # Pass AWS environment variables
  for var in AWS_PROFILE AWS_REGION AWS_DEFAULT_REGION; do
    if [[ -n "${!var:-}" ]]; then
      ENV_ARGS+=(--env "${var}=${!var}")
    fi
  done

  # Pass Anthropic model configuration
  for var in ANTHROPIC_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_HAIKU_MODEL ANTHROPIC_DEFAULT_OPUS_MODEL ANTHROPIC_SMALL_FAST_MODEL; do
    if [[ -n "${!var:-}" ]]; then
      ENV_ARGS+=(--env "${var}=${!var}")
    fi
  done
fi

# Determine which hosts to allow
ALLOW_HOSTS=(
  --allow-host "api.anthropic.com"
  --allow-host "platform.claude.com"
)

if [[ "${USE_AWS}" == "true" ]]; then
  ALLOW_HOSTS+=(
    --allow-host "*.amazonaws.com"
    --allow-host "bedrock-runtime.*.amazonaws.com"
  )
fi

# Build mount arguments
MOUNT_ARGS=(
  --mount-hostfs "${MOUNT_DIR}:/workspace"
)

# Only mount AWS credentials if using --aws flag
if [[ "${USE_AWS}" == "true" ]]; then
  MOUNT_ARGS+=(--mount-hostfs "${HOME}/.aws:/root/.aws:ro")
fi

# Build additional arguments
EXTRA_ARGS=()

# Only use --cwd and --cmd with local gondolin (npx version doesn't support them)
if [[ "${USE_LOCAL_GONDOLIN:-1}" == "1" ]]; then
  EXTRA_ARGS+=(--cwd /workspace --cmd /usr/local/bin/claude)
fi

exec ${GONDOLIN_CMD} bash \
  "${MOUNT_ARGS[@]}" \
  "${ALLOW_HOSTS[@]}" \
  ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"} \
  ${ENV_ARGS[@]+"${ENV_ARGS[@]}"}
