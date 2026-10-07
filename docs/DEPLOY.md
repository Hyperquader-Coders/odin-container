# Deploy

The image publishes to Docker Hub as `hyperquader/odin-container`
(`$DOCKER_USER/odin-container` — `IMAGE` in the Makefile overrides the
namespace if it ever moves).

## Publishing by hand

```sh
make deploy    # build -> check -> tag -> docker save -> crane push
```

Needs `DOCKER_USER` and `DOCKER_TOKEN` (a Docker Hub access token, not the
account password) in the environment; `deploy` fails loudly if either is
unset.

Publishing goes through [crane](https://github.com/google/go-containerregistry),
not `docker push` — `deploy` `docker save`s the built image to a tarball, logs
crane in with `DOCKER_CONFIG` pointed at a throwaway directory under
`build/`, and pushes from there. This never runs a plain `docker login`,
which would write to `~/.docker/config.json` and change what every other
`docker` command on the machine authenticates as. The throwaway config and
tarball are removed at the end of the target whether it succeeds or fails.

`deploy` never pushes `:build` directly — `tag` derives the real version tag
first from the image's own `odin version` output, so `latest` and the pinned
tag always move together and a pull always resolves to a build that passed
`check`. `latest` is added with `crane tag`, which points a new tag at the
already-uploaded manifest rather than re-uploading it.

## When to publish

Publishing is never automatic. A new image goes out by hand, once the
`amber-odin` package it installs has proved itself on the suite: the deb is
in the archive and installed here, `amber-rebuild.sh` has built every suite
repo with it, and their `make ci` passes. Only then `make deploy`, so a
pulled image always carries an odin the suite is known to build with.

## CI

`.github/workflows/build.yml` runs `make ci` (build, leak check, the
packaged binaries) on every push and on demand. It never publishes and holds
no Docker Hub token. It runs on GitHub's own runners (`ubuntu-latest`): the
repo is public, and the org's self-hosted runner is for private repos only.

## Rotating the Docker Hub token

If `DOCKER_TOKEN` is ever compromised, revoke it from Docker Hub's Account
Settings → Security → Access Tokens, issue a new one, and update the local
environment. A revoked
token fails `crane auth login` inside `deploy` immediately rather than
pushing silently to the wrong place.
