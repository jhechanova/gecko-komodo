#!/usr/bin/env bash
# Build an App Store IPA named: komodo-yyyyMMdd-HHmmss.ipa
#
# Prerequisites (do these BEFORE running this script):
#
# 1. Bump the version in pubspec.yaml.
#    Format:  version: <versionName>+<buildNumber>
#    Example: 1.0.0+2  ->  1.0.0+3   (or 1.0.1+3 if the user-facing version also changes)
#
#    The number after '+' is iOS CFBundleVersion (build number). App Store Connect
#    requires it to be unique and strictly higher than every build already uploaded
#    for this app (TestFlight or App Store).
#
#    Reusing a build number fails upload with:
#      "The bundle version must be higher than the previously uploaded version."
#
#    Increment +N every time you upload a new IPA. versionName (CFBundleShortVersionString)
#    only needs to change when the store-facing version changes.
#
# 2. Xcode signing must work on this Mac:
#      - Signed in to Xcode → Settings → Accounts with the Apple Developer team
#      - Runner target uses Automatic signing for bundle id com.gecko.komodo
#      - A distribution certificate and App Store provisioning profile exist
#    First-time setup: open ios/Runner.xcworkspace in Xcode, select Runner →
#    Signing & Capabilities, pick the team, then build once.
#
# 3. For production push on the uploaded build, Runner.entitlements should use
#      aps-environment = production
#    (the repo currently has development).
#
# Usage:
#   ./scripts/build_ipa.sh
set -euo pipefail

PREFIX="komodo"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION_LINE="$(awk '/^version:/{ print $2; exit }' pubspec.yaml)"
VERSION_NAME="${VERSION_LINE%%+*}"
BUILD_NUMBER="${VERSION_LINE##*+}"

if [[ -z "${VERSION_LINE}" || "${VERSION_NAME}" == "${VERSION_LINE}" ]]; then
  echo "error: could not parse 'version: x.y.z+N' from pubspec.yaml" >&2
  exit 1
fi

echo "Building IPA: versionName=${VERSION_NAME}  buildNumber=${BUILD_NUMBER}"
echo "If this buildNumber was already uploaded to App Store Connect, bump the +N in pubspec.yaml first."
echo

flutter build ipa --release --export-method app-store

IPA_DIR="build/ios/ipa"
if [[ ! -d "${IPA_DIR}" ]]; then
  echo "error: missing ${IPA_DIR}" >&2
  exit 1
fi

SRC="$(find "${IPA_DIR}" -maxdepth 1 -type f -name '*.ipa' ! -name "${PREFIX}-*.ipa" | head -n 1 || true)"
DST="${IPA_DIR}/${PREFIX}-${TIMESTAMP}.ipa"

if [[ -z "${SRC}" || ! -f "${SRC}" ]]; then
  latest="$(ls -t "${IPA_DIR}"/${PREFIX}-*.ipa 2>/dev/null | head -n 1 || true)"
  if [[ -n "${latest}" && -f "${latest}" ]]; then
    echo "iOS IPA: ${latest}"
    echo "versionName=${VERSION_NAME}  buildNumber=${BUILD_NUMBER}"
    exit 0
  fi
  echo "error: no IPA found in ${IPA_DIR}" >&2
  exit 1
fi

# Drop previous dated IPAs so only the current release artifact remains.
find "${IPA_DIR}" -maxdepth 1 -type f -name "${PREFIX}-*.ipa" -delete

mv "${SRC}" "${DST}"

echo "iOS IPA: ${DST}"
echo "versionName=${VERSION_NAME}  buildNumber=${BUILD_NUMBER}"
echo "Upload this IPA with Transporter, Xcode Organizer, or App Store Connect → TestFlight."
