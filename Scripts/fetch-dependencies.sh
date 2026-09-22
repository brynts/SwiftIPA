#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDOR="$ROOT/Vendor"
ZSIGN_DIR="$VENDOR/zsign"
ZSIGN_REPO="https://github.com/zhlynn/zsign.git"
ZSIGN_REF="${ZSIGN_REF:-master}"
OPENSSL_INCLUDE_DIR="$VENDOR/openssl-include/openssl"
OPENSSL_RELEASE_API="https://api.github.com/repos/krzyzanowskim/OpenSSL/releases/latest"

mkdir -p "$VENDOR"

if [ -d "$ZSIGN_DIR/.git" ]; then
  echo "==> Updating zsign"
  git -C "$ZSIGN_DIR" fetch --depth 1 origin "$ZSIGN_REF"
  git -C "$ZSIGN_DIR" checkout -q FETCH_HEAD
else
  echo "==> Cloning zsign"
  rm -rf "$ZSIGN_DIR"
  git clone --depth 1 --branch "$ZSIGN_REF" "$ZSIGN_REPO" "$ZSIGN_DIR"
fi

echo "==> Checking the sources SwiftIPA expects"
for file in src/bundle.cpp src/bundle.h src/openssl.cpp src/openssl.h src/macho.cpp src/macho.h src/archo.cpp src/archo.h src/signing.cpp src/signing.h src/common/common.h src/common/mach-o.h; do
  if [ ! -f "$ZSIGN_DIR/$file" ]; then
    echo "    missing: $file (zsign moved things around again, check ZSignBridge.mm and project.yml)" >&2
  fi
done

echo "==> Fetching OpenSSL headers for zsign's #include <openssl/...>"
rm -rf "$VENDOR/openssl-include"
mkdir -p "$OPENSSL_INCLUDE_DIR"

TMP_ZIP="$(mktemp)"
TMP_EXTRACT="$(mktemp -d)"
trap 'rm -f "$TMP_ZIP"; rm -rf "$TMP_EXTRACT"' EXIT

DOWNLOAD_URL=$(curl -fsSL "$OPENSSL_RELEASE_API" | grep -o '"browser_download_url": *"[^"]*OpenSSL.xcframework.zip"' | head -1 | sed -E 's/.*"(https[^"]+)"/\1/')
if [ -z "$DOWNLOAD_URL" ]; then
  echo "    could not resolve the latest OpenSSL.xcframework.zip release asset" >&2
  exit 1
fi

curl -fsSL -o "$TMP_ZIP" "$DOWNLOAD_URL"
unzip -q "$TMP_ZIP" -d "$TMP_EXTRACT" "OpenSSL.xcframework/ios-arm64/OpenSSL.framework/Headers/*"

HEADERS_SRC="$TMP_EXTRACT/OpenSSL.xcframework/ios-arm64/OpenSSL.framework/Headers"
if [ ! -d "$HEADERS_SRC" ]; then
  echo "    OpenSSL's xcframework layout changed, check Scripts/fetch-dependencies.sh" >&2
  exit 1
fi

cp "$HEADERS_SRC"/*.h "$OPENSSL_INCLUDE_DIR/"

echo
echo "Done. Now run:"
echo "  xcodegen generate"
echo "  open SwiftIPA.xcodeproj"
