# Architecture

One `Dockerfile`, no code. The interesting decisions are which archive to
trust and how a build proves what it shipped.

## Build

```
ubuntu:24.04
  -> install ca-certificates, curl, gnupg
  -> add the Amber Linux archive keyring + sources.list.d entry
  -> apt-get install amber-odin amber-ols
  -> odin version && command -v ols   (fails the build if either is missing)
```

`ODIN_VERSION` (a build arg) pins the `amber-odin` package version, e.g.
`2026.08+dev-1` — the same pin `setup-amber-odin`'s `version` input takes.
Empty installs the newest version in the archive at build time.

## Trusting the archive

The keyring and `signed-by` line are the same ones `setup-amber-odin` uses on
a GitHub runner: apt is pinned to the **Amber Linux Archive Signing Key**
(`481A11AA548332196B290D09C5B067A799C43065`) alone, never `[trusted=yes]`.
See [`amberlinux-apt`'s docs/ARCHITECTURE.md](https://github.com/Hyperquader-Coders/amberlinux-apt/blob/main/docs/ARCHITECTURE.md)
for how that archive itself is built and signed.

## Why `amber-ols` comes along for free

`amber-ols` declares `Depends: amber-odin`, so `apt-get install amber-odin
amber-ols` can never resolve to a mismatched pair — the server always matches
the compiler it was built against. There is no build arg to exclude it: an
image with the compiler and not the server saves a few megabytes and buys
nothing, since both come from the same `apt-get install` line.

## Versioning the pushed image

`make tag` runs the just-built `:build` image, reads `odin version` back out
of it, and tags with that string (`:` swapped for `-`) plus `:latest`. This
mirrors `amber-odin`'s own `RELEASE.md` — a built artefact says what it
carries rather than a human tracking it separately. See `docs/DEPLOY.md` for
the full publish sequence.

## Image metadata

The image carries the standard
[OCI annotations](https://github.com/opencontainers/image-spec/blob/main/annotations.md):
`title`, `description`, `source`, `licenses`, `vendor`, `base.name`, plus
`revision` (the git commit the image was built from) and `created` (a UTC
timestamp), both passed in as build args by `make build` so the `LABEL`
instruction itself never changes between builds. It sits last in the
Dockerfile, after every `apt-get` layer — those two values change on every
build, and placing them early would bust the cache for every layer below.
There is no label for the installed `odin`/`ols` version: the image tag
already carries it, so a second copy would only drift from the first.

## Why Ubuntu and not Debian

`amber-odin`'s `.deb` is built and checked against `noble` (Linux Mint 22+),
not Debian — `dpkg-shlibdeps` records the `noble` library versions it links
against. Installing it on `debian:bookworm-slim` would need those runtime
dependencies verified separately; `ubuntu:24.04` is the platform the package
already proves itself on in `amber-odin`'s own `make check`.
