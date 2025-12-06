#!/bin/bash
# Uninstall script for Pleb Client
# Removes desktop file and icons installed by install.sh

set -e

echo "Uninstalling Pleb Client..."

# Remove desktop file
rm -f "$HOME/.local/share/applications/pleb-client.desktop"

# Remove icons
rm -f "$HOME/.local/share/icons/hicolor/256x256/apps/pleb-client.png"
rm -f "$HOME/.local/share/icons/hicolor/scalable/apps/pleb-client.svg"

# Update icon cache
if command -v gtk-update-icon-cache &> /dev/null; then
    gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
fi

# Update desktop database
if command -v update-desktop-database &> /dev/null; then
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
fi

echo "✓ Pleb Client uninstalled successfully!"
