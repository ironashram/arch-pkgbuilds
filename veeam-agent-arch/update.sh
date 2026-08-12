#!/bin/bash
set -euo pipefail

conf_dir=${ARCH_PKGBUILDS_CONF:-$HOME/.config/arch-pkgbuilds}
[[ -f "$conf_dir/env" ]] && . "$conf_dir/env"

VBR=${VBR:-vbr}
REDIST=/opt/veeam/redist/val/x64/rpm
S3=${S3:?set S3 bucket url}
S3_ENDPOINT=${S3_ENDPOINT:?set S3 endpoint url}
REPO=$(cd "$(dirname "$0")" && pwd)

remote_ver=$(ssh "$VBR" "ls $REDIST" \
  | grep -oE 'veeam-([0-9]+\.){3}[0-9]+-1\.el10\.x86_64\.rpm$' \
  | sed -E 's/veeam-(.+)-1\.el10\.x86_64\.rpm/\1/' \
  | sort -V | awk 'END{print}')

local_ver=$(sed -nE 's/^pkgver=(.+)/\1/p' "$REPO/PKGBUILD")

echo "remote: $remote_ver"
echo "local:  $local_ver"

if [[ "$remote_ver" == "$local_ver" ]]; then
  echo "up to date"
  exit 0
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

files=(
  "veeam-${remote_ver}-1.el10.x86_64.rpm"
  "veeam-libs-${remote_ver}-1.x86_64.rpm"
  "blksnap-${remote_ver}-1.noarch.rpm"
)

for f in "${files[@]}"; do
  scp "${VBR}:${REDIST}/${f}" "$work/${f}"
done

for f in "${files[@]}"; do
  aws --endpoint-url "$S3_ENDPOINT" s3 cp "$work/${f}" "${S3}${f}"
done

sed -i "s/^pkgver=.*/pkgver=${remote_ver}/" \
  "$REPO/PKGBUILD" "$REPO/../veeamblksnap-dkms/PKGBUILD"

for d in "$REPO" "$REPO/../veeamblksnap-dkms"; do
  (cd "$d" && SRCDEST=/var/tmp/arch-pkgbuilds/src updpkgsums)
done

echo "bumped pkgver to $remote_ver in both PKGBUILDs"
