# Gondolin + Claude Code

Successfully running Claude Code 2.1.39 inside a Gondolin sandboxed VM with Alpine Linux.

---

## 1. Building the Image

### Prerequisites

**Install e2fsprogs** (required for building ext4 images):

```bash
# macOS
brew install e2fsprogs

# Linux (Debian/Ubuntu)
sudo apt install e2fsprogs
```

### Build

```bash
./build-image.sh
```

This script automatically:
- Clones Gondolin source
- Downloads Claude Code package
- Builds the base Gondolin image
- Injects Claude Code into the rootfs

### Verify

```bash
./test-image.sh
```

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

## Scripts

- **`build-image.sh`** - Build complete image (handles all prerequisites)
- **`test-image.sh`** - Verify installation works
- **`gondolin-claude.sh`** - Launch interactive shell (daily use)
