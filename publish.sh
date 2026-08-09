#!/bin/bash
set -euo pipefail

repo=$HOME/arch-local-repo/x86_64
[[ $# -ge 1 ]] || {
  echo "usage: publish.sh <pkgfile>..." >&2
  exit 1
}

added=()
for f in "$@"; do
  cp -v "$f" "$repo/"
  added+=("$repo/$(basename "$f")")
done

repo-add "$repo/arch-local-repo.db.tar.gz" "${added[@]}"
chmod 644 "${added[@]}" "$repo"/arch-local-repo.db.tar.gz "$repo"/arch-local-repo.files.tar.gz
aws --profile versity s3 sync "$repo/" s3://arch-local-repo/x86_64/
