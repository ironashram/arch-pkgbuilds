#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

report() {
  jq -c 'select(.event == "updated")' \
    | while read -r line; do
        pkg=$(jq -r .name <<<"$line")
        new=$(jq -r .version <<<"$line")
        old=$(sed -nE 's/^pkgver=(.+)/\1/p' "$pkg/PKGBUILD")
        [[ "$new" == "$old" || "${new%%-*}" == "$old" || "$old" == "$new".* ]] && continue
        echo "$pkg: $old -> $new"
      done
}

nvchecker -c nvchecker.toml --failures --logger json 2>/dev/null | report

nvchecker -c nvchecker-veeam.toml --logger json 2>/dev/null | report || true
