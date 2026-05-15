#!/bin/bash
set -eo pipefail

echo "Installing xcodegen..."
brew install xcodegen

# Make sure brew-installed binaries are on PATH for the rest of this script.
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

echo "Generating BufoKeyboard.xcodeproj from project.yml..."
cd "$CI_PRIMARY_REPOSITORY_PATH"
xcodegen generate

echo "Done."
