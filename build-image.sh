#!/usr/bin/env bash
set -euo pipefail

# Build Gondolin image with Claude Code embedded
# This script handles all prerequisites and builds the complete image

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CLAUDE_STANDALONE="${SCRIPT_DIR}/claude-code-standalone"
CUSTOM_IMAGE_DIR="${SCRIPT_DIR}/custom-gondolin-assets"
ROOTFS_IMAGE="${CUSTOM_IMAGE_DIR}/rootfs.ext4"
DEBUGFS="/opt/homebrew/opt/e2fsprogs/sbin/debugfs"
GONDOLIN_SRC="/tmp/gondolin"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🏗️  Gondolin + Claude Code Image Builder"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ============================================================================
# Step 1: Check e2fsprogs
# ============================================================================
echo "1️⃣  Checking e2fsprogs..."
if [[ ! -x "${DEBUGFS}" ]]; then
    echo "   ❌ e2fsprogs not found!"
    echo ""
    echo "   Please install e2fsprogs first:"
    echo "   - macOS: brew install e2fsprogs"
    echo "   - Linux: sudo apt install e2fsprogs"
    echo ""
    exit 1
else
    echo "   ✅ e2fsprogs already installed"
fi

# Add e2fsprogs to PATH
export PATH="/opt/homebrew/opt/e2fsprogs/sbin:/opt/homebrew/opt/e2fsprogs/bin:$PATH"

# ============================================================================
# Step 2: Clone Gondolin source if needed
# ============================================================================
echo ""
echo "2️⃣  Checking Gondolin source..."
if [[ ! -d "${GONDOLIN_SRC}" ]]; then
    echo "   ⚠️  Gondolin source not found, cloning..."
    git clone https://github.com/earendil-works/gondolin "${GONDOLIN_SRC}"
    echo "   ✅ Gondolin source cloned"
else
    echo "   ✅ Gondolin source already available"
fi

# ============================================================================
# Step 3: Extract Claude Code package if needed
# ============================================================================
echo ""
echo "3️⃣  Checking Claude Code package..."
if [[ ! -d "${CLAUDE_STANDALONE}" ]]; then
    echo "   ⚠️  Claude Code package not found, downloading..."
    mkdir -p "${CLAUDE_STANDALONE}"
    cd /tmp
    curl -L https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-2.1.39.tgz -o claude.tgz
    tar -xzf claude.tgz
    cp -r package/* "${CLAUDE_STANDALONE}/"
    rm -rf package claude.tgz
    cd "${SCRIPT_DIR}"
    echo "   ✅ Claude Code package extracted"
else
    echo "   ✅ Claude Code package already available"
fi

# ============================================================================
# Step 4: Build base Gondolin image
# ============================================================================
echo ""
echo "4️⃣  Building base Gondolin image..."
if [[ -d "${CUSTOM_IMAGE_DIR}" ]]; then
    echo "   ⚠️  Removing existing image..."
    rm -rf "${CUSTOM_IMAGE_DIR}"
fi

export GONDOLIN_GUEST_SRC="${GONDOLIN_SRC}/guest"

echo "   Building with config: gondolin-build-config-claude.json"
npx @earendil-works/gondolin build \
    --config gondolin-build-config-claude.json \
    --output ./custom-gondolin-assets

echo "   ✅ Base image built successfully"

# ============================================================================
# Step 5: Inject Claude Code into rootfs
# ============================================================================
echo ""
echo "5️⃣  Injecting Claude Code into rootfs..."
echo ""
echo "   Source: ${CLAUDE_STANDALONE}"
echo "   Target: ${ROOTFS_IMAGE}"
echo ""

# Create a backup
echo "   📦 Creating backup..."
cp "${ROOTFS_IMAGE}" "${ROOTFS_IMAGE}.backup"

# Create temporary directory for staging
STAGE_DIR=$(mktemp -d)
trap "rm -rf '${STAGE_DIR}'" EXIT

echo "   📁 Creating directory structure in image..."

# Create /opt/claude directory using debugfs
${DEBUGFS} -w -R "mkdir /opt" "${ROOTFS_IMAGE}" 2>/dev/null || true
${DEBUGFS} -w -R "mkdir /opt/claude" "${ROOTFS_IMAGE}"

echo "   📂 Copying Claude Code files..."

# Function to add file to ext4 using debugfs
add_file() {
    local src="$1"
    local dest="$2"

    if [[ -f "${src}" ]]; then
        ${DEBUGFS} -w -R "write ${src} ${dest}" "${ROOTFS_IMAGE}" 2>&1 | grep -v "^debugfs"
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
            echo "      Adding: ${dest_dir}/${basename}"
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
        echo "      ${basename}"
        add_file "${item}" "/opt/claude/${basename}"
    elif [[ -d "${item}" ]]; then
        basename=$(basename "${item}")
        echo "      ${basename}/ (directory)"
        add_directory "${item}" "/opt/claude/${basename}"
    fi
done

echo ""
echo "   📝 Creating claude wrapper script..."

# Create wrapper script in temp file
cat > "${STAGE_DIR}/claude" <<'EOF'
#!/bin/bash
exec node /opt/claude/cli.js "$@"
EOF

# Add wrapper to image
${DEBUGFS} -w -R "mkdir /usr/local/bin" "${ROOTFS_IMAGE}" 2>/dev/null || true
add_file "${STAGE_DIR}/claude" "/usr/local/bin/claude"

# Make it executable
echo "      Setting permissions..."
${DEBUGFS} -w -R "set_inode_field /usr/local/bin/claude mode 0100755" "${ROOTFS_IMAGE}" 2>&1 | grep -v "^debugfs"

echo "   ✅ Claude Code injected successfully"

# ============================================================================
# Done!
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Image build complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 Image size:"
ls -lh "${ROOTFS_IMAGE}" | awk '{print "   " $5}'
echo ""
echo "🧪 To test the image, run:"
echo "   ./test-image.sh"
echo ""
echo "🚀 To use the image, run:"
echo "   ./gondolin-claude.sh"
echo ""
