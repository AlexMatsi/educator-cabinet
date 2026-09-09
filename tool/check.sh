#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
export CI=true FLUTTER_SUPPRESS_ANALYTICS=true

flutter --no-version-check pub get --enforce-lockfile
git diff --exit-code -- pubspec.lock
git diff --check
dart format --output=none --set-exit-if-changed lib test
flutter --no-version-check analyze --no-pub
flutter --no-version-check test --no-pub
flutter --no-version-check build web --no-pub
