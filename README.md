# [Gondolin](https://github.com/earendil-works/gondolin) + Claude Code

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

**For standard Claude API users**:
```bash
./gondolin-claude.sh --mount ~/your/folder
```

**For AWS Bedrock users** (automatically configures AWS credentials and model profiles):
```bash
./gondolin-claude.sh --mount ~/your/folder --aws
```

The script starts a VM with:
- Claude Code at `/usr/local/bin/claude`
- Specified repo mounted at `/workspace`
- Working directory set to `/workspace`
- AWS credentials mounted (only with `--aws` flag)

### Inside the VM

```bash
# Already in /workspace
pwd  # /workspace

# Run Claude Code (PATH includes /usr/local/bin automatically)
claude --version
claude --help
```

### Script Options

**`gondolin-claude.sh`**:

```bash
# Standard Claude API usage
./gondolin-claude.sh --mount ~/your/folder

# AWS Bedrock usage (uses your current AWS profile)
./gondolin-claude.sh --mount ~/your/folder --aws

# With specific AWS profile and region
export AWS_PROFILE=your-profile
export AWS_REGION=us-east-1
./gondolin-claude.sh --mount ~/your/folder --aws
```

**Options:**
- `--mount <directory>` - (Required) Directory to mount at `/workspace`
- `--aws` - Enable AWS Bedrock support with:
  - AWS credentials mounted at `/root/.aws` (read-only)
  - `CLAUDE_CODE_USE_BEDROCK=1` set automatically
  - AWS environment variables passed: `AWS_PROFILE`, `AWS_REGION`, `AWS_DEFAULT_REGION`
  - Anthropic model configuration passed: `ANTHROPIC_MODEL`, `ANTHROPIC_DEFAULT_SONNET_MODEL`, etc.
  - AWS Bedrock network access enabled: `*.amazonaws.com`, `bedrock-runtime.*.amazonaws.com`

The script automatically passes all `CLAUDE_CODE_*` environment variables to the VM.

### Single Command (Without Shell)

```bash
GONDOLIN_GUEST_DIR=./custom-gondolin-assets \
  npx @earendil-works/gondolin exec -- /usr/local/bin/claude --version
```

---

## Network Configuration

Claude Code requires these hosts:
- `api.anthropic.com` - API access
- `platform.claude.com` - Authentication (**required**)
- `*.amazonaws.com` - Bedrock support (enabled with `--aws` flag)
- `bedrock-runtime.*.amazonaws.com` - Bedrock runtime (enabled with `--aws` flag)

The script configures network access based on whether `--aws` is specified.

---

## Scripts

- **`build-image.sh`** - Build complete image (handles all prerequisites)
- **`test-image.sh`** - Verify installation works
- **`gondolin-claude.sh`** - Main wrapper for Claude Code
