#!/bin/bash

# Setup script for EFB Agent Xcode project
# This script helps set up the Xcode project structure

set -e

echo "EFB Agent Project Setup"
echo "======================"

# Check if we're in the right directory
if [ ! -f "Package.swift" ]; then
    echo "Error: Must run from project root directory"
    exit 1
fi

# Check for XcodeGen
if ! command -v xcodegen &> /dev/null; then
    echo ""
    echo "XcodeGen not found. Installing via Mint or Homebrew..."
    echo ""
    echo "To install XcodeGen:"
    echo "  brew install xcodegen"
    echo "  OR"
    echo "  mint install yonaskolb/XcodeGen"
    echo ""
    echo "Alternatively, you can manually create the project in Xcode:"
    echo "  1. Open Xcode"
    echo "  2. Create new iOS App project"
    echo "  3. Follow PROJECT_SETUP.md instructions"
    echo ""
    exit 1
fi

echo "Generating Xcode project..."
xcodegen generate

echo ""
echo "Opening Xcode project..."
open EFB-Agent.xcodeproj

echo ""
echo "✅ Project setup complete!"
echo ""
echo "Next steps:"
echo "1. Open EFB-Agent.xcodeproj in Xcode"
echo "2. Select your development team in Signing & Capabilities"
echo "3. Build and run (Cmd+R)"
