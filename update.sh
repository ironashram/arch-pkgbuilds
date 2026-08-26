#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

conf_dir=${ARCH_PKGBUILDS_CONF:-$HOME/.config/arch-pkgbuilds}
[[ -f "$conf_dir/env" ]] && . "$conf_dir/env"

if [[ "${1:-}" == "--alert" ]]; then
  : "${ALERTMANAGER_URL:?set ALERTMANAGER_URL}"
  ends=$(date -u -d '+2 hours' +%Y-%m-%dT%H:%M:%SZ)
  jq -n --arg e "$ends" \
    '[{labels: {alertname: "ArchPkgbuildsUpdateFailed", severity: "critical",
                instance: "arch-pkgbuilds"},
       annotations: {summary: "arch-pkgbuilds unattended update failed",
                     description: "journalctl --user -u arch-pkgbuilds-update.service"},
       endsAt: $e}]' \
    | curl -sS -m 10 -H "Content-Type: application/json" -d @- \
        "$ALERTMANAGER_URL/api/v2/alerts"
  exit 0
fi

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

veeam_mirror() {
  local ver=$1 f
  : "${S3:?set S3 bucket url}" "${S3_ENDPOINT:?set S3 endpoint url}"
  for f in "veeam-${ver}-1.el10.x86_64.rpm" \
    "veeam-libs-${ver}-1.x86_64.rpm" \
    "blksnap-${ver}-1.noarch.rpm"; do
    scp "${VBR:-vbr}:/opt/veeam/redist/val/x64/rpm/${f}" "$SRCDEST/${f}"
    aws ${S3_PROFILE:+--profile $S3_PROFILE} --endpoint-url "$S3_ENDPOINT" \
      s3 cp "$SRCDEST/${f}" "${S3}${f}"
  done
}

veeam_update() {
  local ver=${1:-}
  [[ -n "$ver" ]] || ver=$(nvchecker -c nvchecker-veeam.toml --logger json 2>/dev/null \
    | jq -r 'select(.event == "updated").version')
  [[ -n "$ver" && "$ver" != null ]] || {
    echo "no veeam version - appliance ssh enabled?" >&2
    return 1
  }
  veeam_mirror "$ver"
  build_one veeam-agent-arch "$ver"
  build_one veeamblksnap-dkms "$ver"
}

built_list=$(mktemp)
trap 'rm -f "$built_list"' EXIT
failed=()

if [[ $# -eq 0 ]]; then
  updates=$(./check.sh)
  while read -r line; do
    [[ -z "$line" ]] && continue
    pkg=${line%%:*}
    ver=${line##* }
    case $pkg in
    plex-htpc)
      echo "skipping plex-htpc - use plex-htpc/update.sh" >&2
      continue
      ;;
    veeam-agent-arch)
      veeam_update "$ver" || {
        echo "FAILED: veeam" >&2
        failed+=(veeam)
      }
      continue
      ;;
    esac
    build_one "$pkg" "$ver" || {
      echo "FAILED: $pkg" >&2
      failed+=("$pkg")
    }
  done <<<"$updates"
else
  case $1 in
  veeam-agent-arch | veeamblksnap-dkms)
    veeam_update "${2:-}"
    ;;
  plex-htpc)
    echo "use plex-htpc/update.sh" >&2
    exit 1
    ;;
  *)
    build_one "$1" "${2:-}"
    ;;
  esac
fi

if [[ -s "$built_list" ]]; then
  echo "built:"
  cat "$built_list"
  xargs -a "$built_list" "$conf_dir/publish.sh"
  if ! git diff --quiet; then
    git pull --ff-only
    git add -A
    git commit -sS -m "auto-update: $(sed 's|.*/||; s/\.pkg\.tar\.zst$//' "$built_list" | tr '\n' ' ')"
    git push
  fi
else
  echo "nothing to build"
fi

((${#failed[@]} == 0)) || exit 1
