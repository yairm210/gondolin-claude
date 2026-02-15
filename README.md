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

### Installation (Optional)

To make the script callable from anywhere, add this repository to your PATH:

```bash
# From within the gondolin-claude directory
# For bash (~/.bashrc or ~/.bash_profile)
echo "export PATH=\"$(pwd):\$PATH\"" >> ~/.bashrc

# For zsh (~/.zshrc)
echo "export PATH=\"$(pwd):\$PATH\"" >> ~/.zshrc
```

Then reload your shell or run `source ~/.zshrc` (or `~/.bashrc`).

### Usage

```bash
./gondolin-claude.sh [OPTIONS] [-- CLAUDE_ARGS...]
```

**Options:**

| Option | Input | Description |
|--------|-------|-------------|
| `--mount` | `<directory>` | Directory to mount at `/workspace` (defaults to current directory) |
| `--aws` | (none) | Enable AWS Bedrock support with credentials and model profiles |
| `--` | `CLAUDE_ARGS...` | Pass remaining arguments to Claude Code (e.g., `--fast`, `--model opus`) |

**Example:**

```bash
# Minimal usage (mounts current directory)
./gondolin-claude.sh

# All options combined
./gondolin-claude.sh --mount ~/dev/project --aws -- --fast
```

The script starts a VM with:
- Your directory mounted at `/workspace` and set as working directory
- Claude running from that directory
- AWS credentials mounted (only with `--aws` flag)

---

## Network Configuration

Claude Code requires these hosts:
- `api.anthropic.com` - API access
- `platform.claude.com` - Authentication (**required**)
- `*.amazonaws.com` - Bedrock support (enabled with `--aws` flag)
- `bedrock-runtime.*.amazonaws.com` - Bedrock runtime (enabled with `--aws` flag)
