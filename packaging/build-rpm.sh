#!/bin/bash
set -e

VERSION="0.1.2"
PACKAGE_NAME="pleb-client"
BUILD_DIR="build/rpm"

echo "Building RPM package for $PACKAGE_NAME $VERSION..."

# Clean and create build directories
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
mkdir -p "build"

# Build the application first
echo "Building application..."
cargo build --release

# Create tarball for RPM
echo "Creating source tarball..."
TARBALL_DIR="$BUILD_DIR/SOURCES/${PACKAGE_NAME}-${VERSION}"
mkdir -p "$TARBALL_DIR"
cp -r target resources packaging Cargo.toml Cargo.lock build.rs src qml "$TARBALL_DIR/"
cd "$BUILD_DIR/SOURCES"
tar czf "${PACKAGE_NAME}-${VERSION}.tar.gz" "${PACKAGE_NAME}-${VERSION}"
rm -rf "${PACKAGE_NAME}-${VERSION}"
cd -

# Copy spec file
cp packaging/rpm/pleb-client.spec "$BUILD_DIR/SPECS/"

# Build RPM
echo "Building RPM..."
rpmbuild --define "_topdir $(pwd)/$BUILD_DIR" \
         --define "_builddir $(pwd)/$BUILD_DIR/BUILD" \
         -bb "$BUILD_DIR/SPECS/pleb-client.spec"

# Move RPM to build directory
find "$BUILD_DIR/RPMS" -name "*.rpm" -exec mv {} build/ \;
echo "RPM package created in build/"
