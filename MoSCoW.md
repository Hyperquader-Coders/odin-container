# MoSCoW

The MoSCoW method is a prioritization technique used in management, business analysis, project management, and software development to reach a common understanding with stakeholders on the importance they place on the delivery of each requirement; it is also known as MoSCoW prioritization or MoSCoW analysis.

The term MoSCoW itself is an acronym derived from the first letter of each of four prioritization categories (Must have, Should have, Could have, and Won't have), with the interstitial Os added to make the word pronounceable. While the Os are usually in lower-case to indicate that they do not stand for anything, the all-capitals MOSCOW is also used.

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
