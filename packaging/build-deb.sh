#!/bin/bash
set -e

VERSION="0.1.2"
PACKAGE_NAME="pleb-client"
BUILD_DIR="build/deb"
INSTALL_ROOT="$BUILD_DIR/${PACKAGE_NAME}_${VERSION}_amd64"

echo "Building Debian package for $PACKAGE_NAME $VERSION..."

# Clean and create build directory
rm -rf "$BUILD_DIR"
mkdir -p "$INSTALL_ROOT/DEBIAN"
mkdir -p "$INSTALL_ROOT/usr/bin"
mkdir -p "$INSTALL_ROOT/usr/share/applications"
mkdir -p "$INSTALL_ROOT/usr/share/icons/hicolor/256x256/apps"
mkdir -p "$INSTALL_ROOT/usr/share/icons/hicolor/scalable/apps"

# Build the application
echo "Building application..."
cargo build --release

# Copy files
echo "Copying files..."
cp target/release/pleb_client_qt "$INSTALL_ROOT/usr/bin/"
cp resources/pleb-client.desktop "$INSTALL_ROOT/usr/share/applications/"
cp resources/icons/icon-256.png "$INSTALL_ROOT/usr/share/icons/hicolor/256x256/apps/pleb-client.png"
cp resources/icons/icon.svg "$INSTALL_ROOT/usr/share/icons/hicolor/scalable/apps/pleb-client.svg"

# Copy control files
cp packaging/deb/control "$INSTALL_ROOT/DEBIAN/"
cp packaging/deb/postinst "$INSTALL_ROOT/DEBIAN/"
chmod 755 "$INSTALL_ROOT/DEBIAN/postinst"

# Set permissions
chmod 755 "$INSTALL_ROOT/usr/bin/pleb_client_qt"

# Calculate installed size
INSTALLED_SIZE=$(du -sk "$INSTALL_ROOT" | cut -f1)
echo "Installed-Size: $INSTALLED_SIZE" >> "$INSTALL_ROOT/DEBIAN/control"

# Build the package
echo "Building .deb package..."
dpkg-deb --build "$INSTALL_ROOT"

mv "$BUILD_DIR/${PACKAGE_NAME}_${VERSION}_amd64.deb" "build/"
echo "Package created: build/${PACKAGE_NAME}_${VERSION}_amd64.deb"
