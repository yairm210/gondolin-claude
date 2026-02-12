# Gondolin + Claude Code

Run Claude Code inside a Gondolin sandboxed VM with Alpine Linux.

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

- Clones Gondolin source
- Downloads Claude Code package
- Builds the base Gondolin image
- Injects Claude Code into the rootfs

### Verify

```bash
./test-image.sh
```

## 2. Using the Image

### Quick Start

**Launch interactive shell**:
```bash
./gondolin-claude-bedrock.sh --mount ~/your/folder
```

This starts a VM with:
- Claude Code at `/usr/local/bin/claude`
- Specified repo mounted at `/workspace`
- AWS credentials mounted at `/root/.aws` (read-only)
- Internet access enabled for Claude API and AWS Bedrock

### Inside the VM

```bash
# Already in /workspace
pwd  # /workspace

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

```bash
# Using AWS Bedrock with specific profile
export CLAUDE_CODE_USE_BEDROCK=1
export AWS_PROFILE=your-profile
export AWS_REGION=your-region
./gondolin-claude-bedrock.sh --mount ~/your/folder
```

---

## Network Configuration

Claude Code requires these hosts:
- `api.anthropic.com` - API access
- `platform.claude.com` - Authentication (**required**)
- `*.amazonaws.com` - Bedrock support (if using AWS Bedrock)

The `gondolin-claude-bedrock.sh` script includes all required hosts automatically and passes AWS credentials and Anthropic model configuration to the VM.

---

## Scripts

- **`build-image.sh`** - Build complete image (handles all prerequisites)
- **`test-image.sh`** - Verify installation works
- **`gondolin-claude-bedrock.sh`** - Launch interactive shell with Bedrock support (daily use)
