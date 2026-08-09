# arch-pkgbuilds

PKGBUILDs for the packages published to my private pacman repository. Self-contained home
for all packaging after the AUR shutdown: sources are vendor artifacts or real upstream
release tarballs, nothing is fetched from the AUR.

One directory per package:

| package | source |
|---|---|
| archiso-systemd-boot | own package, custom [archiso](https://gitlab.archlinux.org/archlinux/archiso) rescue ISO |
| helm-docs | [norwoodj/helm-docs](https://github.com/norwoodj/helm-docs) release binary |
| metapac | [ripytide/metapac](https://github.com/ripytide/metapac) release tarball (crates.io) |
| openconnect-fortinet-saml | own package, source at [ironashram/openconnect-fortinet-saml](https://github.com/ironashram/openconnect-fortinet-saml) |
| plex-htpc | [Plex HTPC](https://snapcraft.io/plex-htpc) snap repack |
| plex-media-server-plexpass | [Plex Media Server](https://www.plex.tv/media-server-downloads/) plexpass channel .deb |
| slack-desktop | [Slack](https://slack.com/downloads/linux) vendor .deb |
| systemd-boot-pacman-hook | static pacman hook running [bootctl](https://www.freedesktop.org/software/systemd/man/latest/bootctl.html) update |
| tuxedo-control-center-bin | [TUXEDO Control Center](https://gitlab.com/tuxedocomputers/development/packages/tuxedo-control-center) vendor .deb |
| tuxedo-drivers-dkms | [tuxedocomputers/tuxedo-drivers](https://gitlab.com/tuxedocomputers/development/packages/tuxedo-drivers) release tarball |
| veeam-agent-arch | [Veeam Agent for Linux](https://repository.veeam.com/backup/linux/agent/) RPM repack |
| veeamblksnap-dkms | [Veeam](https://repository.veeam.com/backup/linux/agent/) blksnap RPM repack |
| visual-studio-code-bin | [Microsoft VS Code](https://code.visualstudio.com/) vendor tarball |
| zwait | own package, source at [ironashram/zwait](https://github.com/ironashram/zwait) |

## Update flow

- `./check.sh` - queries every upstream (`nvchecker.toml`) and prints `pkg: old -> new`
  for anything outdated. Needs `nvchecker` and `jq`.
- `./update.sh <pkg> [version]` - bumps pkgver (resolves the version via nvchecker when
  omitted), resets pkgrel, `updpkgsums`, builds with `makepkg`. Needs `pacman-contrib`.
- `./publish.sh <pkgfile>...` - copies into the local repo staging dir, `repo-add`,
  `aws s3 sync` to the bucket.

Special cases with their own driver: `veeam-agent-arch/update.sh` (mirrors the RPMs and
bumps both veeam PKGBUILDs), `plex-htpc/update.sh` (resolves snap revision and hash).
