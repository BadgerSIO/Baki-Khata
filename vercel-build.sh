#!/bin/bash
set -e

echo "==> Setting up Flutter SDK on Vercel..."
if ! command -v flutter &> /dev/null; then
  if [ ! -x "/tmp/flutter/bin/flutter" ]; then
    rm -rf /tmp/flutter
    git clone https://github.com/flutter/flutter.git --depth 1 -b stable /tmp/flutter
  fi
  export PATH="/tmp/flutter/bin:$PATH"
fi

git config --global --add safe.directory /tmp/flutter || true

echo "==> Checking Flutter version..."
flutter --version
flutter config --no-analytics

echo "==> Resolving dependencies..."
flutter pub get

echo "==> Building Flutter Web..."
flutter build web --release

echo "==> Copying static legal pages (privacy, terms, delete-account)..."
cp -f web/privacy.html web/terms.html web/delete-account.html build/web/ 2>/dev/null || true

echo "==> Flutter Web build completed successfully!"
