# arch-pkgbuilds

PKGBUILDs for the packages published to my private pacman repository. Sources are vendor
artifacts or real upstream release tarballs, nothing is fetched from the AUR.

## Why

Created after the August 2026
[AUR malicious packages incident](https://archlinux.org/news/active-aur-malicious-packages-incident/),
when the AUR was locked down under a wave of malicious package adoptions and updates.
Rather than wait it out, every AUR package I used moved here: reviewed once, then
maintained against upstream directly. Every source is checksum-pinned and every built
package and the repository database are GPG-signed, so the chain runs from upstream to
my machines with no third-party packaging layer in between.

One directory per package:

| package | source |
|---|---|
| archiso-systemd-boot | [official Arch release ISO](https://archlinux.org/download/) repack as a rescue boot entry |
| helm-docs | [norwoodj/helm-docs](https://github.com/norwoodj/helm-docs) release binary |
| metapac | [ripytide/metapac](https://github.com/ripytide/metapac) release tarball (crates.io) |
| openconnect-fortinet-saml | [ironashram/openconnect-fortinet-saml](https://github.com/ironashram/openconnect-fortinet-saml) |
| plex-htpc | [Plex HTPC](https://snapcraft.io/plex-htpc) snap repack |
| plex-media-server-plexpass | [Plex Media Server](https://www.plex.tv/media-server-downloads/) plexpass channel .deb |
| slack-desktop | [Slack](https://slack.com/downloads/linux) vendor .deb |
| systemd-boot-pacman-hook | [bootctl](https://www.freedesktop.org/software/systemd/man/latest/bootctl.html) update |
| tuxedo-control-center-bin | [TUXEDO Control Center](https://gitlab.com/tuxedocomputers/development/packages/tuxedo-control-center) vendor .deb |
| tuxedo-drivers-dkms | [tuxedocomputers/tuxedo-drivers](https://gitlab.com/tuxedocomputers/development/packages/tuxedo-drivers) release tarball |
| veeam-agent-arch | [Veeam Agent for Linux](https://repository.veeam.com/backup/linux/agent/) RPM repack |
| veeamblksnap-dkms | [Veeam](https://repository.veeam.com/backup/linux/agent/) blksnap RPM repack |
| visual-studio-code-bin | [Microsoft VS Code](https://code.visualstudio.com/) vendor tarball |
| zwait | [ironashram/zwait](https://github.com/ironashram/zwait) |

## Update flow

- `./check.sh` - queries every upstream (`nvchecker.toml`) and prints `pkg: old -> new`
  for anything outdated. Needs `nvchecker` and `jq`.
- `./update.sh [pkg] [version]` - bumps pkgver (resolves the version via nvchecker when
  omitted), resets pkgrel, `updpkgsums`, builds with `makepkg`, publishes the result.
  With no arguments it builds and publishes everything `check.sh` reports and commits
  the bumps - the single check-build-publish command. Needs `pacman-contrib`.
- Deployment specifics live outside this repo in `~/.config/arch-pkgbuilds/`
  (override with `ARCH_PKGBUILDS_CONF`): an `env` file sourced by the scripts, the
  `publish.sh` that signs and syncs to the repository storage, and systemd user units
  for unattended timer runs. `update.sh --alert` posts a failure alert to the
  Alertmanager named by `ALERTMANAGER_URL`.
- Packages and db are signed; clients pin the repository to
  `SigLevel = Required TrustedOnly`.

Special cases with their own driver: `veeam-agent-arch/update.sh` (mirrors the RPMs and
bumps both veeam PKGBUILDs), `plex-htpc/update.sh` (resolves snap revision and hash).
