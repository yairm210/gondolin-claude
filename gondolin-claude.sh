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
LOCAL_CLAUDE_SETTINGS=false
CLAUDE_ARGS=()
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
        --local-claude-settings)
            LOCAL_CLAUDE_SETTINGS=true
            shift
            ;;
        --)
            shift
            CLAUDE_ARGS=("$@")
            break
            ;;
        *)
            echo "❌ Unknown argument: $1"
            echo "Usage: $0 [--mount <directory>] [--aws] [--local-claude-settings] [-- CLAUDE_ARGS...]"
            exit 1
            ;;
    esac
done

# Default to current working directory if no mount specified
if [[ -z "${MOUNT_DIR}" ]]; then
    MOUNT_DIR="$(pwd)"
    echo "ℹ️  No mount directory specified, using current directory: ${MOUNT_DIR}"
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
  --mount-hostfs "${MOUNT_DIR}:/workspace:rw"
)

# Only mount AWS credentials if using --aws flag
if [[ "${USE_AWS}" == "true" ]]; then
  MOUNT_ARGS+=(--mount-hostfs "${HOME}/.aws:/root/.aws:ro")
fi

# Create a temporary directory for Claude settings if requested
# This allows Claude in the VM to make required changes
CLAUDE_SETTINGS_TEMP=""
if [[ "${LOCAL_CLAUDE_SETTINGS}" == "true" ]]; then
  if [[ -d "${HOME}/.claude" ]]; then
    CLAUDE_SETTINGS_TEMP=$(mktemp -d)

    # Copy CLAUDE.md if it exists
    if [[ -f "${HOME}/.claude/CLAUDE.md" ]]; then
      cp "${HOME}/.claude/CLAUDE.md" "${CLAUDE_SETTINGS_TEMP}/"
    fi

    # Copy skills directory if it exists
    if [[ -d "${HOME}/.claude/skills" ]]; then
      cp -r "${HOME}/.claude/skills" "${CLAUDE_SETTINGS_TEMP}/"
    fi

    # Mount the temp directory
    MOUNT_ARGS+=(--mount-hostfs "${CLAUDE_SETTINGS_TEMP}:/tmp/claude-settings-host:ro")
  else
    echo "⚠️  Warning: ~/.claude directory not found, skipping"
  fi
fi

# Build the startup command
STARTUP_CMD="/usr/local/bin/claude"
if [[ ${#CLAUDE_ARGS[@]} -gt 0 ]]; then
  STARTUP_CMD="${STARTUP_CMD} ${CLAUDE_ARGS[*]}"
fi

# If copying Claude settings, prepend copy commands
if [[ -n "${CLAUDE_SETTINGS_TEMP}" ]]; then
  STARTUP_CMD="mkdir -p /root/.claude && cp -r /tmp/claude-settings-host/* /root/.claude/ 2>/dev/null || true && ${STARTUP_CMD}"
fi

# Execute differently based on whether using local gondolin
if [[ "${USE_LOCAL_GONDOLIN:-1}" == "1" ]]; then
  # Local gondolin supports -- syntax and --cwd
  exec ${GONDOLIN_CMD} bash \
    "${MOUNT_ARGS[@]}" \
    "${ALLOW_HOSTS[@]}" \
    ${ENV_ARGS[@]+"${ENV_ARGS[@]}"} \
    --cwd /workspace \
    -- bash -c "${STARTUP_CMD}"
else
  # npx version doesn't support -- syntax or --cwd
  exec ${GONDOLIN_CMD} bash \
    "${MOUNT_ARGS[@]}" \
    "${ALLOW_HOSTS[@]}" \
    ${ENV_ARGS[@]+"${ENV_ARGS[@]}"}
fi
