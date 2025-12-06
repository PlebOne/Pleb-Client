#!/bin/bash
set -e

VERSION="0.1.0"
APP_ID="one.pleb.PlebClient"
BUILD_DIR="build/flatpak"
REPO_DIR="build/flatpak-repo"

echo "Building Flatpak for $APP_ID $VERSION..."

# Clean build directories
rm -rf "$BUILD_DIR" "$REPO_DIR"
mkdir -p "$BUILD_DIR" "$REPO_DIR" "build"

# Generate cargo sources for offline build
echo "Generating cargo sources..."
if ! command -v flatpak-cargo-generator.py &> /dev/null; then
    # Download the generator if not available
    if [ ! -f "/tmp/flatpak-cargo-generator.py" ]; then
        curl -L -o /tmp/flatpak-cargo-generator.py \
            https://raw.githubusercontent.com/nicokoch/flatpak-cargo-generator/master/flatpak-cargo-generator.py
        chmod +x /tmp/flatpak-cargo-generator.py
    fi
    CARGO_GENERATOR="/tmp/flatpak-cargo-generator.py"
else
    CARGO_GENERATOR="flatpak-cargo-generator.py"
fi

python3 "$CARGO_GENERATOR" Cargo.lock -o packaging/flatpak/cargo-sources.json

# Install required SDK extensions
echo "Installing Flatpak SDK extensions..."
flatpak install -y flathub org.kde.Platform//6.7 org.kde.Sdk//6.7 || true
flatpak install -y flathub org.freedesktop.Sdk.Extension.rust-stable//24.08 || true
flatpak install -y flathub org.freedesktop.Sdk.Extension.llvm18//24.08 || true

# Build the Flatpak
echo "Building Flatpak..."
cd packaging/flatpak
flatpak-builder --force-clean --repo="../../$REPO_DIR" "../../$BUILD_DIR" "$APP_ID.yml"

# Create the bundle
echo "Creating Flatpak bundle..."
flatpak build-bundle "../../$REPO_DIR" "../../build/${APP_ID}-${VERSION}.flatpak" "$APP_ID"

cd ../..
echo "Flatpak created: build/${APP_ID}-${VERSION}.flatpak"
