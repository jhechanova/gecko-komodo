#!/usr/bin/env bash
# Build an Android App Bundle named: komodo-yyyyMMdd-HHmmss.aab
#
# Prerequisites (do these BEFORE running this script):
#
# 1. Bump the version in pubspec.yaml.
#    Format:  version: <versionName>+<versionCode>
#    Example: 1.0.0+1  ->  1.0.0+2   (or 1.0.1+2 if the user-facing version also changes)
#
#    The number after '+' is Android versionCode. Play Console requires it to be
#    unique and strictly higher than every AAB already uploaded to ANY track
#    (Internal testing, Closed, Open, Production).
#
#    Reusing a versionCode fails upload with:
#      "Version code N has already been used. Try another version code."
#
#    The first Internal testing upload used versionCode 1, so the next Play
#    upload must use 2 or higher. Increment it every time you upload a new AAB.
#
# 2. Signing files must exist (gitignored):
#      android/key.properties
#      android/upload-keystore.jks
#    See android/PLAY_CONSOLE_CHECKLIST.txt.
#
# Usage:
#   ./scripts/build_aab.sh
set -euo pipefail

PREFIX="komodo"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION_LINE="$(awk '/^version:/{ print $2; exit }' pubspec.yaml)"
VERSION_NAME="${VERSION_LINE%%+*}"
VERSION_CODE="${VERSION_LINE##*+}"

if [[ -z "${VERSION_LINE}" || "${VERSION_NAME}" == "${VERSION_LINE}" ]]; then
  echo "error: could not parse 'version: x.y.z+N' from pubspec.yaml" >&2
  exit 1
fi

echo "Building AAB: versionName=${VERSION_NAME}  versionCode=${VERSION_CODE}"
echo "If this versionCode was already uploaded to Play Console, bump the +N in pubspec.yaml first."
echo

flutter build appbundle --release

AAB_DIR="build/app/outputs/bundle/release"
SRC="${AAB_DIR}/app-release.aab"
DST="${AAB_DIR}/${PREFIX}-${TIMESTAMP}.aab"

if [[ ! -f "${SRC}" ]]; then
  latest="$(ls -t "${AAB_DIR}"/${PREFIX}-*.aab 2>/dev/null | head -n 1 || true)"
  if [[ -n "${latest}" && -f "${latest}" ]]; then
    echo "Android AAB: ${latest}"
    echo "versionName=${VERSION_NAME}  versionCode=${VERSION_CODE}"
    exit 0
  fi
  echo "error: missing ${SRC}" >&2
  exit 1
fi

# Drop previous dated AABs so only the current release artifact remains.
find "${AAB_DIR}" -maxdepth 1 -type f \( -name "${PREFIX}-*.aab" -o -name "${PREFIX}-*.aab.sha1" \) -delete

mv "${SRC}" "${DST}"
if [[ -f "${SRC}.sha1" ]]; then
  mv "${SRC}.sha1" "${DST}.sha1"
fi

echo "Android AAB: ${DST}"
echo "versionName=${VERSION_NAME}  versionCode=${VERSION_CODE}"
echo "Upload this AAB to Play Console Internal testing (or the next track)."
