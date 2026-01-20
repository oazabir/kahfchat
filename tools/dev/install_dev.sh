#!/usr/bin/env bash
set -euo pipefail

# Fast dev install for macOS + emulator.
# Usage: tools/dev/install_dev.sh [abi] [-- <extra gradle args>]

ABI_ARG="${1:-}"
shift || true

EXTRA_GRADLE_ARGS=()
if [[ "${1:-}" == "--" ]]; then
  shift
  EXTRA_GRADLE_ARGS=("$@")
fi

resolve_abi() {
  if [[ -n "$ABI_ARG" ]]; then
    echo "$ABI_ARG"
    return
  fi

  if command -v adb >/dev/null 2>&1; then
    local abi
    abi="$(adb shell getprop ro.product.cpu.abi 2>/dev/null | tr -d '\r')"
    if [[ -n "$abi" ]]; then
      echo "$abi"
      return
    fi
  fi

  local os arch
  os="$(uname -s)"
  arch="$(uname -m)"
  if [[ "$os" == "Darwin" && "$arch" == "arm64" ]]; then
    echo "arm64-v8a"
  else
    echo "x86_64"
  fi
}

ABI="$(resolve_abi)"

echo "Using ABI: $ABI"

./gradlew :app:installGplayDebug -PdevBuild=true -PdevAbi="$ABI" "${EXTRA_GRADLE_ARGS[@]}"
