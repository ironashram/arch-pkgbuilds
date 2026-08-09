#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

pkg=$1
case $pkg in
veeam-agent-arch | veeamblksnap-dkms)
  echo "use veeam-agent-arch/update.sh" >&2
  exit 1
  ;;
plex-htpc)
  echo "use plex-htpc/update.sh" >&2
  exit 1
  ;;
esac

ver=${2:-$(nvchecker -c nvchecker.toml -e "$pkg" --logger json 2>/dev/null \
  | jq -r 'select(.event == "updated").version')}
[[ -n "$ver" && "$ver" != null ]] || {
  echo "no version for $pkg" >&2
  exit 1
}

base=${ver%%-*}
sed -i "s/^pkgver=.*/pkgver=$base/" "$pkg/PKGBUILD"
sed -i "s/^pkgrel=.*/pkgrel=1/" "$pkg/PKGBUILD"
if [[ $pkg == plex-media-server-plexpass ]]; then
  sed -i "s/^_pkgsum=.*/_pkgsum=${ver#*-}/" "$pkg/PKGBUILD"
fi

export BUILDDIR=/var/tmp/arch-pkgbuilds/build
export SRCDEST=/var/tmp/arch-pkgbuilds/src
export PKGDEST=/var/tmp/arch-pkgbuilds/pkg
mkdir -p "$BUILDDIR" "$SRCDEST" "$PKGDEST"

(cd "$pkg" && updpkgsums && makepkg -dcf --noconfirm)
echo "built $pkg $base - publish with: ./publish.sh $PKGDEST/<file>"
