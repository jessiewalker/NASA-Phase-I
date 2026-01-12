#!/bin/bash
# Setup script for EFB Agent Xcode project generation

set -e

echo "EFB Agent Project Setup"
echo "======================="

# Check if xcodegen is installed
if ! command -v xcodegen &> /dev/null; then
    echo "Error: xcodegen is not installed"
    echo "Install with: brew install xcodegen"
    exit 1
fi

echo "Generating Xcode project from project.yml..."
xcodegen generate

echo "Opening Xcode project..."
open EFB-Agent.xcodeproj

echo "Setup complete!"
echo ""
echo "Next steps:"
echo "1. Select your development team in Xcode (Signing & Capabilities)"
echo "2. Select iPad as the run destination"
echo "3. Build and run (Cmd+R)"

