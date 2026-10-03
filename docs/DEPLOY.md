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

## Publishing from CI

`.github/workflows/build-publish.yml` runs `make ci` (build + check, no
push) on every push, and `make deploy` only on `workflow_dispatch` or the
monthly schedule — the same cadence `amber-odin` tracks upstream Odin on, so
this image picks up a new package roughly when one exists to pick up.

The workflow needs `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` as **repository
secrets** (Settings → Secrets and variables → Actions) — the same Docker Hub
access token used locally, added there separately since GitHub Actions does
not read this machine's environment. `gh secret set DOCKERHUB_TOKEN` from
this repo's checkout sets it without the value ever appearing in a workflow
log.

## Rotating the Docker Hub token

If `DOCKER_TOKEN` is ever compromised, revoke it from Docker Hub's Account
Settings → Security → Access Tokens, issue a new one, and update both the
local environment and the `DOCKERHUB_TOKEN` repository secret. A revoked
token fails `crane auth login` inside `deploy` immediately rather than
pushing silently to the wrong place.
