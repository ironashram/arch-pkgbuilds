# arch-pkgbuilds

PKGBUILDs for the packages published to my private pacman repository. Sources are vendor
artifacts or real upstream release tarballs, nothing is fetched from the AUR.

## Why

Created in August 2026, months into the ongoing AUR malicious-package campaigns
(the [initial incident](https://archlinux.org/news/active-aur-malicious-packages-incident/),
then [pushes disabled entirely](https://lists.archlinux.org/archives/list/aur-general@lists.archlinux.org/thread/DRDEU3JUSC72CB265XHXPFA3DFSLXPBP/)).
Rather than wait it out, every AUR package I used moved here: reviewed once, then maintained against each upstream directly. Every source is checksum-pinned.

One directory per package

`./check.sh` reports outdated packages.
`./update.sh [pkg]` builds and publishes everything outdated.
