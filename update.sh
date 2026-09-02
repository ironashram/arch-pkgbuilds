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
  (cd "$pkg" && makepkg --printsrcinfo >.SRCINFO)
  (cd "$pkg" && makepkg --packagelist) >>"$built_list"
  built_names+="${built_names:+ }$pkg-$base"
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

plex_update() {
  local res id stable rev ver dl snap mnt full hash
  res=$(curl -sS -L -H 'Snap-Device-Series: 16' https://api.snapcraft.io/v2/snaps/info/plex-htpc)
  id=$(jq -r '."snap-id"' <<<"$res")
  stable=$(jq -e '."channel-map"[] | select(.channel.name == "stable")' <<<"$res")
  rev=$(jq -r '.revision' <<<"$stable")
  ver=$(jq -r '.version' <<<"$stable")
  dl=$(jq -r '.download.url' <<<"$stable")
  snap="$SRCDEST/${id}_${rev}.snap"
  [[ -f "$snap" ]] || wget -q -O "$snap" "$dl"

  mnt=$(mktemp -d)
  plex_mnt=$mnt
  sudo mount -t squashfs "$snap" "$mnt"

  full=$ver
  hash=""

  if [[ -f "$mnt/snap/manifest.yaml" ]]; then
    manifest_version=$(grep "^version:" "$mnt/snap/manifest.yaml" | cut -d: -f2 | tr -d ' ')
    if [[ -n "$manifest_version" ]]; then
      full="$manifest_version"
    fi
  fi

  plex_binary=""
  if [[ -f "$mnt/bin/Plex" ]]; then
    plex_binary="$mnt/bin/Plex"
  elif [[ -f "$mnt/Plex" ]]; then
    plex_binary="$mnt/Plex"
  fi

  if [[ -n "$plex_binary" ]]; then
    version_hash_string=$(strings "$plex_binary" | grep -E '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+-[a-f0-9]{8}' | awk 'NR==1{print;exit}' || true)

    if [[ -n "$version_hash_string" ]]; then
      if [[ $version_hash_string =~ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)-([a-f0-9]{8}) ]]; then
        full="${BASH_REMATCH[1]}"
        hash="${BASH_REMATCH[2]}"
      fi
    else
      version_from_binary=$(strings "$plex_binary" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | awk 'NR==1{print;exit}' || true)
      if [[ -n "$version_from_binary" && "$version_from_binary" != "127.0.0.1" ]]; then
        full="$version_from_binary"
      fi
    fi
  fi

  if [[ -z "$hash" ]]; then
    hash=$(grep "^_pkghash=" plex-htpc/PKGBUILD | cut -d= -f2)
  fi

  sudo umount "$mnt"
  rmdir "$mnt"
  plex_mnt=""

  sed -i "s|^\(_pkghash=\).*|\1$hash|" plex-htpc/PKGBUILD
  sed -i "s|^\(_snaprev=\).*|\1$rev|" plex-htpc/PKGBUILD
  build_one plex-htpc "$full"
}

publish_and_commit() {
  [[ -s "$built_list" ]] || return 0
  echo "built:"
  cat "$built_list"
  xargs -a "$built_list" "$conf_dir/publish.sh"
  if ! git diff --quiet -- "$@"; then
    git pull --ff-only
    git add -- "$@"
    git commit -sS -m "auto-update: $built_names"
    git push
  fi
  built=1
  built_names=""
  : >"$built_list"
}

built_list=$(mktemp)
built_names=""
built=0
plex_mnt=""
trap 'rm -f "$built_list"; [[ -n "$plex_mnt" ]] && { sudo umount "$plex_mnt" 2>/dev/null || true; rmdir "$plex_mnt" 2>/dev/null || true; }' EXIT
failed=()

if [[ $# -eq 0 ]]; then
  updates=$(./check.sh)
  while read -r line; do
    [[ -z "$line" ]] && continue
    pkg=${line%%:*}
    ver=${line##* }
    built_names=""
    : >"$built_list"
    case $pkg in
    plex-htpc)
      plex_update && publish_and_commit plex-htpc || {
        echo "FAILED: plex-htpc" >&2
        failed+=(plex-htpc)
      }
      continue
      ;;
    veeam-agent-arch)
      veeam_update "$ver" && publish_and_commit veeam-agent-arch veeamblksnap-dkms || {
        echo "FAILED: veeam" >&2
        failed+=(veeam)
      }
      continue
      ;;
    esac
    build_one "$pkg" "$ver" && publish_and_commit "$pkg" || {
      echo "FAILED: $pkg" >&2
      failed+=("$pkg")
    }
  done <<<"$updates"
else
  case $1 in
  veeam-agent-arch | veeamblksnap-dkms)
    veeam_update "${2:-}" && publish_and_commit veeam-agent-arch veeamblksnap-dkms
    ;;
  plex-htpc)
    plex_update && publish_and_commit plex-htpc
    ;;
  *)
    build_one "$1" "${2:-}" && publish_and_commit "$1"
    ;;
  esac
fi

((built)) || echo "nothing to build"

((${#failed[@]} == 0)) || exit 1
