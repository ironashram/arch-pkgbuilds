#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

export BUILDDIR=/var/tmp/arch-pkgbuilds/build
export SRCDEST=/var/tmp/arch-pkgbuilds/src
export PKGDEST=/var/tmp/arch-pkgbuilds/pkg
mkdir -p "$BUILDDIR" "$SRCDEST" "$PKGDEST"

build_one() {
  local pkg=$1 ver=${2:-}
  [[ -n "$ver" ]] || ver=$(nvchecker -c nvchecker.toml -e "$pkg" --logger json 2>/dev/null \
    | jq -r 'select(.event == "updated").version')
  [[ -n "$ver" && "$ver" != null ]] || {
    echo "no version for $pkg" >&2
    return 1
  }
  local base=${ver%%-*}
  sed -i "s/^pkgver=.*/pkgver=$base/" "$pkg/PKGBUILD"
  sed -i "s/^pkgrel=.*/pkgrel=1/" "$pkg/PKGBUILD"
  if [[ $pkg == plex-media-server-plexpass ]]; then
    sed -i "s/^_pkgsum=.*/_pkgsum=${ver#*-}/" "$pkg/PKGBUILD"
  fi
  (cd "$pkg" && updpkgsums && makepkg -dcf --noconfirm)
  (cd "$pkg" && makepkg --packagelist) >>"$built_list"
}

built_list=$(mktemp)
trap 'rm -f "$built_list"' EXIT

if [[ $# -eq 0 ]]; then
  while read -r line; do
    pkg=${line%%:*}
    ver=${line##* }
    case $pkg in
    veeam-agent-arch | veeamblksnap-dkms | plex-htpc)
      echo "skipping $pkg - use its own update.sh" >&2
      continue
      ;;
    esac
    build_one "$pkg" "$ver"
  done < <(./check.sh)
else
  case $1 in
  veeam-agent-arch | veeamblksnap-dkms)
    echo "use veeam-agent-arch/update.sh" >&2
    exit 1
    ;;
  plex-htpc)
    echo "use plex-htpc/update.sh" >&2
    exit 1
    ;;
  esac
  build_one "$1" "${2:-}"
fi

if [[ -s "$built_list" ]]; then
  echo "built:"
  cat "$built_list"
  xargs -a "$built_list" ./publish.sh
else
  echo "nothing to build"
fi
