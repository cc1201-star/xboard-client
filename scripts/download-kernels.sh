#!/usr/bin/env bash
# Download mihomo (Clash.Meta) kernels for bundling into the Xboard client.
# Run this before `flutter build` so the binaries get packaged with the app.
#
# Targets:
#   - Windows amd64   -> assets/bin/windows/mihomo.exe
#   - macOS amd64     -> assets/bin/macos/mihomo-amd64
#   - macOS arm64     -> assets/bin/macos/mihomo-arm64
#   - Android arm64   -> android/app/src/main/jniLibs/arm64-v8a/libmihomo.so
#   - Android armv7   -> android/app/src/main/jniLibs/armeabi-v7a/libmihomo.so
#   - Android x86_64  -> android/app/src/main/jniLibs/x86_64/libmihomo.so
#
# The Android binaries are renamed to `libmihomo.so` so Android's APK extractor
# places them in nativeLibraryDir (which is executable on Android 10+).

set -euo pipefail

VERSION="${MIHOMO_VERSION:-v1.19.14}"
VER_NUM="${VERSION#v}"
BASE="https://github.com/MetaCubeX/mihomo/releases/download/${VERSION}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ASSETS="${ROOT}/assets/bin"
JNI="${ROOT}/android/app/src/main/jniLibs"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

have() { command -v "$1" >/dev/null 2>&1; }
need() { have "$1" || { echo "missing: $1" >&2; exit 1; }; }
need curl
need gzip

fetch() {
  local url="$1" out="$2"
  echo ">> $url"
  curl -fSL --retry 3 -o "$out" "$url"
}

gunzip_to() {
  local gz="$1" out="$2"
  gunzip -c "$gz" > "$out"
  chmod 0755 "$out"
}

mkdir -p "$ASSETS/windows" "$ASSETS/macos" \
         "$JNI/arm64-v8a" "$JNI/armeabi-v7a" "$JNI/x86_64"

# Windows amd64 (.zip)
if have unzip; then
  ZIP="$TMP/mihomo-win.zip"
  fetch "$BASE/mihomo-windows-amd64-${VERSION}.zip" "$ZIP"
  unzip -o -q "$ZIP" -d "$TMP/win"
  WIN_EXE="$(find "$TMP/win" -name 'mihomo*.exe' | head -n1)"
  cp "$WIN_EXE" "$ASSETS/windows/mihomo.exe"
else
  echo "!! unzip missing, skipping Windows binary"
fi

# macOS amd64 (.gz)
MAC_AMD_GZ="$TMP/mihomo-mac-amd64.gz"
fetch "$BASE/mihomo-darwin-amd64-${VERSION}.gz" "$MAC_AMD_GZ"
gunzip_to "$MAC_AMD_GZ" "$ASSETS/macos/mihomo-amd64"

# macOS arm64 (.gz)
MAC_ARM_GZ="$TMP/mihomo-mac-arm64.gz"
fetch "$BASE/mihomo-darwin-arm64-${VERSION}.gz" "$MAC_ARM_GZ"
gunzip_to "$MAC_ARM_GZ" "$ASSETS/macos/mihomo-arm64"

# Android arm64-v8a (.gz)
AND_ARM64_GZ="$TMP/mihomo-and-arm64.gz"
fetch "$BASE/mihomo-android-arm64-v8-${VERSION}.gz" "$AND_ARM64_GZ"
gunzip_to "$AND_ARM64_GZ" "$JNI/arm64-v8a/libmihomo.so"

# Android armv7 (.gz)
AND_ARM_GZ="$TMP/mihomo-and-arm.gz"
fetch "$BASE/mihomo-android-armv7-${VERSION}.gz" "$AND_ARM_GZ"
gunzip_to "$AND_ARM_GZ" "$JNI/armeabi-v7a/libmihomo.so"

# Android amd64 / x86_64 (.gz)
AND_AMD_GZ="$TMP/mihomo-and-amd64.gz"
fetch "$BASE/mihomo-android-amd64-${VERSION}.gz" "$AND_AMD_GZ"
gunzip_to "$AND_AMD_GZ" "$JNI/x86_64/libmihomo.so"

echo ""
echo "== done =="
echo "mihomo $VERSION placed under:"
echo "  $ASSETS/windows/mihomo.exe"
echo "  $ASSETS/macos/mihomo-amd64"
echo "  $ASSETS/macos/mihomo-arm64"
echo "  $JNI/<abi>/libmihomo.so"
