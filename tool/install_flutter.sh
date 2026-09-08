#!/usr/bin/env bash
set -euo pipefail

version="$(tr -d '[:space:]' < "$(dirname "$0")/../.flutter-version")"
install_dir="${FLUTTER_HOME:-$HOME/flutter}"
archive="flutter_linux_${version}-stable.tar.xz"
url="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/$archive"

if [[ -x "$install_dir/bin/flutter" ]]; then
  actual="$($install_dir/bin/flutter --version --machine | python3 -c 'import json,sys; print(json.load(sys.stdin)["frameworkVersion"])')"
  [[ "$actual" == "$version" ]] || { echo "У $install_dir встановлено Flutter $actual, очікується $version" >&2; exit 1; }
else
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' EXIT
  curl --fail --location --retry 2 --output "$work/$archive" "$url"
  mkdir -p "$(dirname "$install_dir")"
  tar -xf "$work/$archive" -C "$(dirname "$install_dir")"
  [[ "$(dirname "$install_dir")/flutter" == "$install_dir" ]] || mv "$(dirname "$install_dir")/flutter" "$install_dir"
fi

export PATH="$install_dir/bin:$PATH"
flutter config --no-analytics
flutter --version
flutter create --platforms=android,ios,web --project-name=educator_cabinet --org=ua.example .
flutter pub get
printf '\nДодайте до PATH: export PATH="%s/bin:$PATH"\n' "$install_dir"
