# Diagrams

[d2](https://d2lang.com) source with its rendered SVG committed alongside, so it is
viewable without d2 installed. Re-render after editing the source:

```sh
d2 diags/image-pipeline.d2 diags/image-pipeline.svg
```

| Source | Shows |
|---|---|
| [`image-pipeline.d2`](image-pipeline.d2) | how a `.deb` in `amber-odin` becomes a pulled image on a consumer's machine |

## image-pipeline

`amber-odin`'s `make deb-upstream` and `make deb-ols` produce the two packages that
`amberlinux-apt` signs and publishes to `apt.amberlinux.org`. This repo's `Dockerfile`
pins apt to that archive's signing key and installs both — `amber-ols` rides along on
`amber-odin`'s `Depends`, so there is no image with one and not the other. `make deploy`
pushes the result to Docker Hub as `hyperquader/odin-container`.
