# MoSCoW: odin-container

Prioritisation by **Must / Should / Could / Won't have** (the lower-case Os just make it
pronounceable). This is the **scope** document, and it holds only what is **still open**: an
item leaves this file the moment it ships. Nothing here records work done: `git log` is for
that.

An empty band means that band is finished, not that it was never populated.

## Must have

## Should have

- **arm64 image.** `amber-odin`'s Makefile takes `ARCH`, and the upstream Odin
  release may ship an arm64 asset per tag. The Dockerfile is `amd64` only until
  that is confirmed and a multi-arch `docker buildx` target exists.

## Could have

- **The image digest in `amber-odin`'s `RELEASE.md`.** That file records the
  deb's version, size and SHA256; the Docker Hub tag this image publishes for
  the same release belongs beside them, so one document says what shipped
  everywhere.

## Won't have (this time)

- **A GHCR mirror.** Docker Hub is the one registry this image publishes to;
  a second target is a second set of credentials and a second place a tag can
  drift from the first.
