#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

nvchecker -c nvchecker.toml --logger json 2>/dev/null \
  | jq -c 'select(.event == "updated")' \
  | while read -r line; do
      pkg=$(jq -r .name <<<"$line")
      new=$(jq -r .version <<<"$line")
      old=$(sed -nE 's/^pkgver=(.+)/\1/p' "$pkg/PKGBUILD")
      [[ "$new" == "$old" || "${new%%-*}" == "$old" || "$old" == "$new".* ]] && continue
      echo "$pkg: $old -> $new"
    done
