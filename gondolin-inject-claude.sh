#!/usr/bin/env bash
set -euo pipefail

# Inject Claude Code into existing Gondolin rootfs using debugfs (no sudo required)

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CLAUDE_STANDALONE="${HOME}/claude-code-standalone"
CUSTOM_IMAGE_DIR="${SCRIPT_DIR}/custom-gondolin-assets"
ROOTFS_IMAGE="${CUSTOM_IMAGE_DIR}/rootfs.ext4"
DEBUGFS="/opt/homebrew/opt/e2fsprogs/sbin/debugfs"

# Check prerequisites
if [[ ! -d "${CLAUDE_STANDALONE}" ]]; then
    echo "❌ Claude Code standalone package not found at: ${CLAUDE_STANDALONE}"
    echo "Please extract it first."
    exit 1
fi

if [[ ! -f "${ROOTFS_IMAGE}" ]]; then
    echo "❌ Rootfs image not found at: ${ROOTFS_IMAGE}"
    echo "Please build it first with:"
    echo "  export PATH=\"/opt/homebrew/opt/e2fsprogs/sbin:\$PATH\""
    echo "  GONDOLIN_GUEST_SRC=/tmp/gondolin/guest npx @earendil-works/gondolin build --config gondolin-build-config-claude.json --output ./custom-gondolin-assets"
    exit 1
fi

if [[ ! -x "${DEBUGFS}" ]]; then
    echo "❌ debugfs not found at: ${DEBUGFS}"
    exit 1
fi

echo "🔧 Injecting Claude Code into Gondolin rootfs..."
echo ""
echo "   Source: ${CLAUDE_STANDALONE}"
echo "   Target: ${ROOTFS_IMAGE}"
echo ""

# Create a backup
echo "📦 Creating backup..."
cp "${ROOTFS_IMAGE}" "${ROOTFS_IMAGE}.backup"

# Create temporary directory for staging
STAGE_DIR=$(mktemp -d)
trap "rm -rf '${STAGE_DIR}'" EXIT

echo "📁 Creating directory structure in image..."

# Create /opt/claude directory using debugfs
${DEBUGFS} -w -R "mkdir /opt" "${ROOTFS_IMAGE}" 2>/dev/null || true
${DEBUGFS} -w -R "mkdir /opt/claude" "${ROOTFS_IMAGE}"

echo "📂 Copying Claude Code files..."

# Function to add file to ext4 using debugfs
add_file() {
    local src="$1"
    local dest="$2"

    if [[ -f "${src}" ]]; then
        ${DEBUGFS} -w -R "write ${src} ${dest}" "${ROOTFS_IMAGE}"
    fi
}

# Function to recursively add directory
add_directory() {
    local src_dir="$1"
    local dest_dir="$2"

    # Create directory
    ${DEBUGFS} -w -R "mkdir ${dest_dir}" "${ROOTFS_IMAGE}" 2>/dev/null || true

    # Add files
    for item in "${src_dir}"/*; do
        if [[ -f "${item}" ]]; then
            local basename=$(basename "${item}")
            echo "   Adding: ${dest_dir}/${basename}"
            add_file "${item}" "${dest_dir}/${basename}"
        elif [[ -d "${item}" ]]; then
            local basename=$(basename "${item}")
            add_directory "${item}" "${dest_dir}/${basename}"
        fi
    done
}

# Copy all Claude Code files
for item in "${CLAUDE_STANDALONE}"/*; do
    if [[ -f "${item}" ]]; then
        basename=$(basename "${item}")
        echo "   ${basename}"
        add_file "${item}" "/opt/claude/${basename}"
    elif [[ -d "${item}" ]]; then
        basename=$(basename "${item}")
        echo "   ${basename}/ (directory)"
        add_directory "${item}" "/opt/claude/${basename}"
    fi
done

echo ""
echo "📝 Creating claude wrapper script..."

# Create wrapper script in temp file
cat > "${STAGE_DIR}/claude" <<'EOF'
#!/bin/bash
exec node /opt/claude/cli.js "$@"
EOF

# Add wrapper to image
${DEBUGFS} -w -R "mkdir /usr/local/bin" "${ROOTFS_IMAGE}" 2>/dev/null || true
add_file "${STAGE_DIR}/claude" "/usr/local/bin/claude"

# Make it executable (debugfs doesn't support chmod directly, so we use set_inode_field)
echo "   Setting permissions..."
${DEBUGFS} -w -R "set_inode_field /usr/local/bin/claude mode 0100755" "${ROOTFS_IMAGE}"

echo ""
echo "✅ Claude Code injected successfully!"
echo ""
echo "📊 Image size:"
ls -lh "${ROOTFS_IMAGE}" | awk '{print "   " $5}'
echo ""
echo "To test the image:"
echo "  GONDOLIN_GUEST_DIR=${CUSTOM_IMAGE_DIR} npx @earendil-works/gondolin bash"
echo ""
echo "Then inside the VM, run:"
echo "  claude --version"
echo ""
