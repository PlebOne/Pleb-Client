#!/bin/bash
# Install script for Pleb Client
# This sets up the desktop file and icon for proper integration with Plasma/KDE

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Installing Pleb Client..."

# Create directories if they don't exist
mkdir -p "$HOME/.local/share/applications"
mkdir -p "$HOME/.local/share/icons/hicolor/256x256/apps"
mkdir -p "$HOME/.local/share/icons/hicolor/scalable/apps"

# Copy the desktop file
echo "Installing desktop file..."
cp "$PROJECT_DIR/resources/pleb-client.desktop" "$HOME/.local/share/applications/"

# Update the desktop file to point to the correct executable
EXEC_PATH="$PROJECT_DIR/target/release/pleb_client_qt"
sed -i "s|Exec=pleb_client_qt|Exec=$EXEC_PATH|g" "$HOME/.local/share/applications/pleb-client.desktop"

# Copy icons
echo "Installing icons..."
cp "$PROJECT_DIR/resources/icons/icon-256.png" "$HOME/.local/share/icons/hicolor/256x256/apps/pleb-client.png"
cp "$PROJECT_DIR/resources/icons/icon.svg" "$HOME/.local/share/icons/hicolor/scalable/apps/pleb-client.svg"

# Update icon cache
echo "Updating icon cache..."
if command -v gtk-update-icon-cache &> /dev/null; then
    gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
fi

# Update desktop database
if command -v update-desktop-database &> /dev/null; then
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
fi

echo ""
echo "✓ Pleb Client installed successfully!"
echo ""
echo "You can now:"
echo "  1. Find 'Pleb Client' in your application menu"
echo "  2. Pin it to your taskbar/dock"
echo "  3. The icon should now show in the taskbar when running"
echo ""
echo "To uninstall, run: ./uninstall.sh"
