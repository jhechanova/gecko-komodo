#!/usr/bin/env bash
# Build Android/iOS release artifacts named: komodo-yyyyMMdd-HHmmss.{apk,ipa}
set -euo pipefail

usage() {
  echo "Usage: $0 {android|ios|all}"
  exit 1
}

[[ $# -ge 1 ]] || usage

PREFIX="komodo"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

rename_android() {
  local apk_dir="build/app/outputs/flutter-apk"
  local src="${apk_dir}/app-release.apk"
  local dst="${apk_dir}/${PREFIX}-${TIMESTAMP}.apk"

  if [[ ! -f "$src" ]]; then
    # Gradle may have already created a dated copy; prefer the newest komodo-*.apk.
    local latest
    latest="$(ls -t "${apk_dir}"/${PREFIX}-*.apk 2>/dev/null | head -n 1 || true)"
    if [[ -n "${latest}" && -f "${latest}" ]]; then
      echo "Android APK: ${latest}"
      return 0
    fi
    echo "error: missing ${src}" >&2
    exit 1
  fi

  # Drop previous dated APKs so only the current release artifact remains.
  find "${apk_dir}" -maxdepth 1 -type f \( -name "${PREFIX}-*.apk" -o -name "${PREFIX}-*.apk.sha1" \) -delete

  mv "${src}" "${dst}"
  if [[ -f "${src}.sha1" ]]; then
    mv "${src}.sha1" "${dst}.sha1"
  fi
  echo "Android APK: ${dst}"
}

rename_ios() {
  local ipa_dir="build/ios/ipa"
  if [[ ! -d "${ipa_dir}" ]]; then
    echo "error: missing ${ipa_dir}" >&2
    exit 1
  fi

  local src
  src="$(find "${ipa_dir}" -maxdepth 1 -type f -name '*.ipa' ! -name "${PREFIX}-*.ipa" | head -n 1 || true)"
  if [[ -z "${src}" || ! -f "${src}" ]]; then
    local latest
    latest="$(ls -t "${ipa_dir}"/${PREFIX}-*.ipa 2>/dev/null | head -n 1 || true)"
    if [[ -n "${latest}" && -f "${latest}" ]]; then
      echo "iOS IPA: ${latest}"
      return 0
    fi
    echo "error: no IPA found in ${ipa_dir}" >&2
    exit 1
  fi

  find "${ipa_dir}" -maxdepth 1 -type f -name "${PREFIX}-*.ipa" -delete

  local dst="${ipa_dir}/${PREFIX}-${TIMESTAMP}.ipa"
  mv "${src}" "${dst}"
  echo "iOS IPA: ${dst}"
}

case "$1" in
  android)
    flutter build apk --release
    rename_android
    ;;
  ios)
    flutter build ipa --release
    rename_ios
    ;;
  all)
    flutter build apk --release
    rename_android
    flutter build ipa --release
    rename_ios
    ;;
  *)
    usage
    ;;
esac
