#!/usr/bin/env bash

# Setup Rectangle configuration and login items

# Check if Rectangle is installed
if ! [ -d "/Applications/Rectangle.app" ]; then
    echo "Rectangle is not installed yet, skipping setup"
    exit 0
fi

# Copy Rectangle preferences if it exists in config
RECTANGLE_PLIST="$HOME/.config/rectangle/com.knollsoft.Rectangle.plist"
if [ -f "$RECTANGLE_PLIST" ]; then
    cp "$RECTANGLE_PLIST" "$HOME/Library/Preferences/com.knollsoft.Rectangle.plist"
    echo "Rectangle preferences applied"
fi

# Remove old window managers from login items
osascript -e 'tell application "System Events" to delete login item "Hammerspoon"' 2>/dev/null || true
osascript -e 'tell application "System Events" to delete login item "ShiftIt"' 2>/dev/null || true
osascript -e 'tell application "System Events" to delete login item "Spectacle"' 2>/dev/null || true

# Add Rectangle to login items if not already present
if ! osascript -e 'tell application "System Events" to get the name of every login item' | grep -q "Rectangle"; then
    osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/Rectangle.app", hidden:false}' 2>/dev/null || true
    echo "Rectangle added to login items"
fi

# Restart Rectangle to apply changes
killall Rectangle 2>/dev/null || true
open -a Rectangle 2>/dev/null || true

echo "Rectangle setup complete"
