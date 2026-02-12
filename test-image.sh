#!/usr/bin/env bash
set -euo pipefail

# Quick test script for Gondolin + Claude Code

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
IMAGE_DIR="${SCRIPT_DIR}/custom-gondolin-assets"

if [[ ! -d "${IMAGE_DIR}" ]]; then
    echo "❌ Custom image not found at: ${IMAGE_DIR}"
    echo "Please build it first. See README.md for instructions."
    exit 1
fi

echo "🧪 Testing Gondolin + Claude Code Integration"
echo ""

echo "1️⃣  Testing Node.js..."
GONDOLIN_GUEST_DIR="${IMAGE_DIR}" npx @earendil-works/gondolin exec -- node --version
echo ""

echo "2️⃣  Testing Claude Code files..."
GONDOLIN_GUEST_DIR="${IMAGE_DIR}" npx @earendil-works/gondolin exec -- ls -lh /opt/claude/cli.js
echo ""

echo "3️⃣  Testing Claude wrapper script..."
GONDOLIN_GUEST_DIR="${IMAGE_DIR}" npx @earendil-works/gondolin exec -- cat /usr/local/bin/claude
echo ""

echo "4️⃣  Testing Claude Code..."
GONDOLIN_GUEST_DIR="${IMAGE_DIR}" npx @earendil-works/gondolin exec -- /usr/local/bin/claude --version
echo ""

echo "✅ All tests passed!"
echo ""
echo "To start an interactive shell:"
echo "  cd ${SCRIPT_DIR}"
echo "  GONDOLIN_GUEST_DIR=./custom-gondolin-assets npx @earendil-works/gondolin bash --mount-hostfs ~/dev/analytics:/workspace"
echo ""
