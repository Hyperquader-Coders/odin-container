# MoSCoW — odin-container

Prioritisation by **Must / Should / Could / Won't have** (the lower-case Os just make it
pronounceable). This is the **scope** document, and it holds only what is **still open**: an
item leaves this file the moment it ships. Nothing here records work done — `git log` is for
that.

An empty band means that band is finished, not that it was never populated.

## Must have

- nada

## Should have

- **arm64 image.** `amber-odin`'s Makefile threads `ARCH` through already and
  the upstream Odin release may ship an arm64 asset per tag; this Dockerfile
  is `amd64`-only until that is confirmed and a multi-arch `docker buildx`
  target is added.

## Could have

- **Attach the image digest to `amber-odin`'s own `RELEASE.md`.** That file
  already records the deb's version, size and SHA256; the Docker Hub tag this
  image publishes for the same release is a natural addition, so one document
  says what shipped everywhere.

## Won't have (this time)

- **A GHCR mirror.** Docker Hub is the one registry this image publishes to;
  a second target is a second set of credentials and a second place a tag can
  drift from the first.
