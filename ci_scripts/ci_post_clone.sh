#!/bin/bash
set -e

echo "📦 Installing XcodeGen..."
brew install xcodegen

echo "⚙️ Generating Xcode project..."
cd "$CI_PRIMARY_REPOSITORY_PATH"
xcodegen generate

echo "✅ Project generated successfully"
