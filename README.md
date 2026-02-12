# Gondolin + Claude Code

Successfully running Claude Code 2.1.39 inside a Gondolin sandboxed VM with Alpine Linux.

---

## 1. Building the Image

### Prerequisites

1. **Extract Claude Code package**:
   ```bash
   mkdir -p ~/claude-code-standalone
   cd /tmp
   curl -L https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-2.1.39.tgz -o claude.tgz
   tar -xzf claude.tgz
   cp -r package/* ~/claude-code-standalone/
   ```

2. **Install e2fsprogs** (if not already installed):
   ```bash
   brew install e2fsprogs
   ```

3. **Clone Gondolin source** (if not already cloned):
   ```bash
   git clone https://github.com/earendil-works/gondolin /tmp/gondolin
   ```

### Build Steps

1. **Build base Gondolin image**:
   ```bash
   export PATH="/opt/homebrew/opt/e2fsprogs/sbin:/opt/homebrew/opt/e2fsprogs/bin:$PATH"
   export GONDOLIN_GUEST_SRC=/tmp/gondolin/guest

   npx @earendil-works/gondolin build \
     --config gondolin-build-config-claude.json \
     --output ./custom-gondolin-assets
   ```

2. **Inject Claude Code into the image**:
   ```bash
   ./gondolin-inject-claude.sh
   ```

3. **Verify installation**:
   ```bash
   ./gondolin-test.sh
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
| Test fails | Re-run `./gondolin-inject-claude.sh` |
| Build fails | Check e2fsprogs is in PATH |

---

## What's Inside

- **VM Image**: 268MB (Alpine Linux 3.23, Node.js 24.13, Claude Code 2.1.39)
- **Boot time**: ~2-3 seconds
- **Claude location**: `/opt/claude/` (embedded in rootfs)
- **Wrapper script**: `/usr/local/bin/claude`
- **PATH**: Pre-configured to include `/usr/local/bin`

---

## Scripts

- `gondolin-claude.sh` - Launch interactive shell (daily use)
- `gondolin-test.sh` - Verify installation works
- `gondolin-inject-claude.sh` - Rebuild image with Claude Code
