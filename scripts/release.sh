#!/bin/bash
set -e

VERSION="0.1.0"
TAG="v$VERSION"

echo "============================================"
echo "Pleb Client v$VERSION Release Script"
echo "============================================"

# Ensure we're on main branch
BRANCH=$(git branch --show-current)
if [ "$BRANCH" != "main" ]; then
    echo "Warning: Not on main branch (currently on $BRANCH)"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Build release binary
echo ""
echo "Step 1: Building release binary..."
cargo build --release

# Create build output directory
mkdir -p build

# Copy binary
cp target/release/pleb_client_qt build/

echo ""
echo "Step 2: Creating release tarball..."
TARBALL="pleb-client-${VERSION}-linux-x86_64.tar.gz"
cd build
tar czf "$TARBALL" pleb_client_qt
cd ..

echo ""
echo "Step 3: Creating DEB package..."
./packaging/build-deb.sh || echo "DEB build failed (might need dpkg-deb)"

echo ""
echo "Step 4: Checking git status..."
if ! git diff --quiet; then
    echo "You have uncommitted changes. Committing..."
    git add -A
    git commit -m "Release v$VERSION" || true
fi

echo ""
echo "Step 5: Pushing to GitHub..."
git push origin main

echo ""
echo "Step 6: Creating GitHub release..."

# Check if gh is installed
if ! command -v gh &> /dev/null; then
    echo "GitHub CLI (gh) is not installed. Please install it first."
    echo "  Fedora: sudo dnf install gh"
    echo "  Ubuntu: sudo apt install gh"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo "Please authenticate with GitHub CLI first: gh auth login"
    exit 1
fi

# Create release notes
RELEASE_NOTES="## Pleb Client v$VERSION

Initial release of Pleb Client - A native Nostr client for Linux.

### Features
- Following feed, replies, and global timeline
- Direct messages (NIP-04 encrypted)
- Notifications for mentions, replies, and zaps
- Profile viewing and editing
- Zaps via Nostr Wallet Connect (NWC)
- Media embedding (images, videos)
- Keyboard navigation
- Dark theme UI

### Downloads
- **Binary**: \`pleb-client-${VERSION}-linux-x86_64.tar.gz\` - Extract and run \`pleb_client_qt\`
- **DEB**: \`pleb-client_${VERSION}_amd64.deb\` - For Debian/Ubuntu: \`sudo dpkg -i pleb-client_${VERSION}_amd64.deb\`

### Requirements
- Qt 6.x (QtQuick, QtMultimedia)
- Linux x86_64

### Links
- Website: https://pleb.one
- Bug Reports: https://pleb.one/projects.html?id=e9ce79cf-6f96-498e-83fa-41f55a01f7aa
- Donations: https://pleb.one/donations.html
"

echo "$RELEASE_NOTES" > build/RELEASE_NOTES.md

# Create the release
echo "Creating release $TAG..."
gh release create "$TAG" \
    --title "Pleb Client $VERSION" \
    --notes-file build/RELEASE_NOTES.md \
    build/pleb-client-${VERSION}-linux-x86_64.tar.gz \
    build/pleb-client_${VERSION}_amd64.deb 2>/dev/null || \
gh release create "$TAG" \
    --title "Pleb Client $VERSION" \
    --notes-file build/RELEASE_NOTES.md \
    build/pleb-client-${VERSION}-linux-x86_64.tar.gz

echo ""
echo "============================================"
echo "Release v$VERSION created successfully!"
echo "============================================"
echo ""
echo "View the release at:"
echo "  https://github.com/PlebOne/Pleb-Client/releases/tag/$TAG"
