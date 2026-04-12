#!/bin/sh
# Codecritter installer — downloads the latest release and installs it.
# Usage: curl -fsSL https://raw.githubusercontent.com/ygalsk/codecritters/main/install.sh | sh

set -e

REPO="ygalsk/codecritters"
INSTALL_DIR="${CODECRITTER_HOME:-$HOME/.local/share/codecritter}"
BIN_DIR="${CODECRITTER_BIN:-$HOME/.local/bin}"

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)  ARCH_LABEL="x86_64" ;;
    aarch64) ARCH_LABEL="aarch64" ;;
    arm64)   ARCH_LABEL="aarch64" ;;
    *)
        echo "Error: unsupported architecture: $ARCH"
        echo "Supported: x86_64, aarch64"
        exit 1
        ;;
esac

# Detect OS
OS=$(uname -s)
case "$OS" in
    Linux)  OS_LABEL="linux" ;;
    Darwin) OS_LABEL="macos" ;;
    *)
        echo "Error: unsupported OS: $OS"
        echo "Supported: Linux, macOS"
        exit 1
        ;;
esac

ASSET_NAME="codecritter-${OS_LABEL}-${ARCH_LABEL}.tar.gz"

echo "Codecritter installer"
echo "  Architecture: ${ARCH_LABEL}"
echo "  OS: ${OS_LABEL}"
echo "  Install to: ${INSTALL_DIR}"
echo ""

# Find the latest release
echo "Finding latest release..."
LATEST_URL=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
    | grep "browser_download_url.*${ASSET_NAME}" \
    | head -1 \
    | cut -d '"' -f 4)

if [ -z "$LATEST_URL" ]; then
    echo "Error: could not find a release for ${ASSET_NAME}"
    echo "Check https://github.com/${REPO}/releases for available downloads."
    echo ""
    echo "Alternatively, build from source:"
    echo "  git clone https://github.com/${REPO}.git"
    echo "  cd codecritters && zig build run"
    exit 1
fi

echo "Downloading ${ASSET_NAME}..."

# Download and extract
mkdir -p "$INSTALL_DIR"
curl -fsSL "$LATEST_URL" | tar xz -C "$INSTALL_DIR"

# Create wrapper script that runs from the install directory
# (the game loads data/ and assets/ relative to CWD)
mkdir -p "$BIN_DIR"
cat > "$BIN_DIR/codecritter" << 'WRAPPER'
#!/bin/sh
CODECRITTER_DIR="${CODECRITTER_HOME:-$HOME/.local/share/codecritter}"
cd "$CODECRITTER_DIR" && exec ./codecritter "$@"
WRAPPER
chmod +x "$BIN_DIR/codecritter"

echo ""
echo "Installed to ${INSTALL_DIR}"
echo "Launcher at ${BIN_DIR}/codecritter"
echo ""

# Check if bin dir is in PATH
case ":$PATH:" in
    *":${BIN_DIR}:"*) ;;
    *)
        echo "Note: ${BIN_DIR} is not in your PATH."
        echo "Add it with:"
        echo "  export PATH=\"${BIN_DIR}:\$PATH\""
        echo ""
        ;;
esac

echo "Run 'codecritter' to play!"
