# arch-pkgbuilds

PKGBUILDs for the packages published to my private pacman repository. Self-contained home
for all packaging after the AUR shutdown: sources are vendor artifacts or real upstream
release tarballs, nothing is fetched from the AUR.

One directory per package:

| package | source |
|---|---|
| archiso-systemd-boot | own package (custom archiso rescue ISO) |
| helm-docs | norwoodj/helm-docs GitHub release binary |
| metapac | ripytide/metapac release tarball (crates.io) |
| openconnect-fortinet-saml | own package, source repo ironashram/openconnect-fortinet-saml |
| plex-htpc | Plex HTPC vendor tarball |
| plex-media-server-plexpass | Plex Media Server plexpass channel .deb |
| slack-desktop | Slack vendor .deb |
| systemd-boot-pacman-hook | static pacman hook running bootctl update |
| tuxedo-control-center-bin | TUXEDO vendor .deb |
| tuxedo-drivers-dkms | TUXEDO GitLab release tarball |
| veeam-agent-arch | Veeam Agent for Linux RPM repack |
| veeamblksnap-dkms | Veeam blksnap RPM repack |
| visual-studio-code-bin | Microsoft VS Code vendor tarball |
| zwait | own package, source repo ironashram/zwait |

Build with `makepkg`, publish with `repo-add` + `aws s3 sync` to the bucket backing the
repository.
