# Spec

`odin-container` is a Docker image carrying the [Odin](https://odin-lang.org)
compiler and OLS, its language server, ready to `docker run` or use as a
`FROM` base. Nothing here is built from source — both binaries are the signed
`.deb`s from [`amber-odin`](https://github.com/Hyperquader-Coders/amber-odin),
installed from the Amber Linux apt archive at build time.

## What the image contains

| | package | binary | on `PATH` |
|---|---|---|---|
| compiler | `amber-odin` | `odin` | `/usr/bin/odin` |
| language server (OLS) | `amber-ols` | `ols` | `/usr/bin/ols` |

Base: `ubuntu:24.04` (noble) — the platform `amber-odin`'s package is built
and checked against. `clang` comes in as `amber-odin`'s own `Depends`; nothing
in this repo names it directly.

## Tags

| tag | points at |
|---|---|
| `latest` | the most recently built image |
| `<odin-version>` | e.g. `dev-2026-08-nightly-902106f` — the exact `odin version` string baked into that build, `:` swapped for `-` since Docker tags forbid it |

A pinned tag never moves once pushed. `latest` moves on every `make deploy`.
Pin the version tag for anything that must stay reproducible.

## Client contract

- `odin version` and `ols` are on `PATH` and executable in every tagged image —
  the build itself fails otherwise, so a pushed tag has already proven this.
- `WORKDIR` is `/workspace`; nothing is copied into it. Mount a source tree
  there (`-v $(pwd):/workspace`) rather than baking one in.
- The image installs only `amber-odin` and `amber-ols` plus their declared
  dependencies (`--no-install-recommends`) — no editor, no extra collections,
  no build tools beyond what the compiler itself needs.

## What this is not

Not a CI action — that is
[`setup-amber-odin`](https://github.com/Hyperquader-Coders/setup-amber-odin),
for GitHub Actions runners specifically. This image is for everything else
that wants the same compiler: other CI systems, local dev, or as a base image
for a downstream `Dockerfile`.
