#!/bin/bash
set -euo pipefail

repo=$HOME/arch-local-repo/x86_64
key=766C2CAD62688604
[[ $# -ge 1 ]] || {
  echo "usage: publish.sh <pkgfile>..." >&2
  exit 1
}

added=()
for f in "$@"; do
  [[ -f "$f.sig" ]] || gpg --detach-sign --no-armor -u "$key" "$f"
  cp -v "$f" "$f.sig" "$repo/"
  added+=("$repo/$(basename "$f")")
done

repo-add --sign --key "$key" "$repo/arch-local-repo.db.tar.gz" "${added[@]}"
chmod 644 "${added[@]}" "${added[@]/%/.sig}" \
  "$repo"/arch-local-repo.db.tar.gz "$repo"/arch-local-repo.db.tar.gz.sig \
  "$repo"/arch-local-repo.files.tar.gz "$repo"/arch-local-repo.files.tar.gz.sig
aws --profile versity s3 sync "$repo/" s3://arch-local-repo/x86_64/
