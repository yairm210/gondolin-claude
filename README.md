# Gondolin + Claude Code

Successfully running Claude Code 2.1.39 inside a Gondolin sandboxed VM with Alpine Linux.

---

## 1. Building the Image

### Prerequisites

**Install e2fsprogs** (required for building ext4 images):
   ```bash
   ./build-image.sh
   ```

   This script will:
   - Install e2fsprogs if needed
   - Clone Gondolin source if needed
   - Download Claude Code package if needed
   - Build the base Gondolin image
   - Inject Claude Code into the rootfs

3. **Verify installation**:
   ```bash
   ./test-image.sh
   ```

Expected output: `✅ All tests passed!`

---

## 2. Using the Image

### Quick Start

**Launch interactive shell**:
```bash
./gondolin-claude.sh
```

This starts a VM with:
- Claude Code at `/usr/local/bin/claude`
- Analytics repo mounted at `/workspace`
- AWS credentials mounted at `/root/.aws` (read-only)
- Internet access enabled for Claude API

### Inside the VM

```bash
# Navigate to workspace
cd /workspace

# Run Claude Code (PATH includes /usr/local/bin automatically)
claude --version
claude --help
```

### Single Command (Without Shell)

```bash
GONDOLIN_GUEST_DIR=./custom-gondolin-assets \
  npx @earendil-works/gondolin exec -- /usr/local/bin/claude --version
```

### Custom Usage

**Mount different directory**:
```bash
GONDOLIN_GUEST_DIR=./custom-gondolin-assets \
  npx @earendil-works/gondolin bash \
  --mount-hostfs /path/to/your/repo:/workspace \
  --allow-host api.anthropic.com \
  --allow-host platform.claude.com
```

**With API key**:
```bash
GONDOLIN_GUEST_DIR=./custom-gondolin-assets \
  npx @earendil-works/gondolin bash \
  --mount-hostfs ~/dev/analytics:/workspace \
  --host-secret ANTHROPIC_API_KEY@api.anthropic.com,platform.claude.com \
  --allow-host api.anthropic.com \
  --allow-host platform.claude.com
```

**With Bedrock**:
```bash
export CLAUDE_CODE_USE_BEDROCK=1
export AWS_REGION=us-east-1
./gondolin-claude.sh
```

---

## Network Configuration

Claude Code requires these hosts:
- `api.anthropic.com` - API access
- `platform.claude.com` - Authentication (**required**)
- `*.amazonaws.com` - Bedrock support (if using AWS Bedrock)

The `gondolin-claude.sh` script includes all required hosts automatically.

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "claude: not found" | Use full path: `/usr/local/bin/claude` |
| "Authentication failed" | Ensure `platform.claude.com` is allowed |
| Test fails | Re-run `./build-image.sh` |
| Build fails | Check error message, may need to run with sudo for brew |

---

## What's Inside

- **VM Image**: 268MB (Alpine Linux 3.23, Node.js 24.13, Claude Code 2.1.39)
- **Boot time**: ~2-3 seconds
- **Claude location**: `/opt/claude/` (embedded in rootfs)
- **Wrapper script**: `/usr/local/bin/claude`
- **PATH**: Pre-configured to include `/usr/local/bin`

---

## Scripts

- **`build-image.sh`** - Build complete image (handles all prerequisites)
- **`test-image.sh`** - Verify installation works
- **`gondolin-claude.sh`** - Launch interactive shell (daily use)
