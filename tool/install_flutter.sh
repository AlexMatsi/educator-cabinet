#!/usr/bin/env bash
set -euo pipefail

# Avoid cloud metadata detection and disable SDK telemetry in this installer.
export CI=true FLUTTER_SUPPRESS_ANALYTICS=true

version="$(tr -d '[:space:]' < "$(dirname "$0")/../.flutter-version")"
install_dir="${FLUTTER_HOME:-$HOME/flutter}"
archive="flutter_linux_${version}-stable.tar.xz"
url="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/$archive"

if [[ -x "$install_dir/bin/flutter" ]]; then
  actual="$("$install_dir/bin/flutter" --version --machine | python3 -c 'import json,sys; print(json.load(sys.stdin)["frameworkVersion"])')"
  [[ "$actual" == "$version" ]] || { echo "У $install_dir встановлено Flutter $actual, очікується $version" >&2; exit 1; }
else
  [[ ! -e "$install_dir" ]] || { echo "Директорія вже існує: $install_dir" >&2; exit 1; }
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' EXIT
  curl --fail --location --retry 2 --output "$work/$archive" "$url"
  mkdir -p "$(dirname "$install_dir")"
  tar --no-same-owner -xf "$work/$archive" -C "$work"
  mv "$work/flutter" "$install_dir"
fi

export PATH="$install_dir/bin:$PATH"
flutter config --no-analytics
flutter --version

printf '\nДодайте до PATH: export PATH="%s/bin:$PATH"\n' "$install_dir"
