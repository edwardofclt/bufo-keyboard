#!/bin/sh
set -euo pipefail

echo "Installing xcodegen..."
brew install xcodegen

echo "Generating BufoKeyboard.xcodeproj from project.yml..."
cd "$CI_PRIMARY_REPOSITORY_PATH"
xcodegen generate

echo "Done."
