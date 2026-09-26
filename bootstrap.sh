#!/usr/bin/env bash
# One-time setup: generates the android/ios/web platform folders around the
# existing lib/, then installs, analyzes and tests.
set -euo pipefail
cd "$(dirname "$0")"

command -v flutter >/dev/null || { echo "Flutter SDK not found. Install from https://flutter.dev"; exit 1; }

if [ ! -d android ] && [ ! -d ios ]; then
  tmp="$(mktemp -d)"
  cp -r lib test pubspec.yaml analysis_options.yaml assets "$tmp"/
  flutter create --project-name hidden_objects --org com.example .
  rm -rf lib test
  cp -r "$tmp"/lib "$tmp"/test .
  cp "$tmp"/pubspec.yaml "$tmp"/analysis_options.yaml .
  rm -rf "$tmp"
fi

flutter pub get
flutter analyze
flutter test
echo "Done. Run the game with: flutter run"
