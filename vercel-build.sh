#!/bin/bash
set -e

echo "==> Setting up Flutter SDK on Vercel..."
if ! command -v flutter &> /dev/null; then
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable /tmp/flutter
  export PATH="/tmp/flutter/bin:$PATH"
fi

flutter --version
flutter config --no-analytics
flutter pub get
flutter build web --release
echo "==> Flutter Web build completed successfully!"
