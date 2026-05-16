#!/bin/sh
set -euo pipefail

echo "Installing xcodegen..."
brew install xcodegen

cd "$CI_PRIMARY_REPOSITORY_PATH"

# --- Bump CFBundleVersion ---------------------------------------------------
# Xcode Cloud guarantees $CI_BUILD_NUMBER is monotonically increasing across
# every run of a given workflow. Patch project.yml before xcodegen runs so the
# generated .xcodeproj has the right value baked into every target.
if [ -n "${CI_BUILD_NUMBER:-}" ]; then
  echo "Setting CURRENT_PROJECT_VERSION = $CI_BUILD_NUMBER"
  sed -i '' "s/^    CURRENT_PROJECT_VERSION: .*/    CURRENT_PROJECT_VERSION: \"$CI_BUILD_NUMBER\"/" project.yml
fi

# --- Bump MARKETING_VERSION on tagged builds --------------------------------
# Tag-triggered workflows are the only ones that submit to the App Store.
# Strip the leading "v" and use it as the user-visible version.
if [ -n "${CI_TAG:-}" ]; then
  VERSION="${CI_TAG#v}"
  echo "Setting MARKETING_VERSION = $VERSION (from tag $CI_TAG)"
  sed -i '' "s/^    MARKETING_VERSION: .*/    MARKETING_VERSION: \"$VERSION\"/" project.yml
fi

echo "Generating BufoKeyboard.xcodeproj from project.yml..."
xcodegen generate

echo "Done."
