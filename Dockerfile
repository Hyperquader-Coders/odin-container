# Odin + OLS on Ubuntu noble, from the signed Amber Linux apt archive —
# no source build, no LLVM toolchain, just an apt-get.
FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg \
    && rm -rf /var/lib/apt/lists/*

# signed-by pins apt to the Amber Linux Archive Signing Key
# (481A11AA548332196B290D09C5B067A799C43065) alone — no [trusted=yes].
RUN install -d -m0755 /usr/share/keyrings \
    && curl -fsSL --retry 3 --retry-delay 2 \
        -o /usr/share/keyrings/amberlinux-archive-keyring.gpg \
        https://apt.amberlinux.org/amberlinux-archive-keyring.gpg \
    && echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/amberlinux-archive-keyring.gpg] https://apt.amberlinux.org amber main' \
        > /etc/apt/sources.list.d/amberlinux.list

# ODIN_VERSION pins amber-odin (e.g. 2026.08+dev-1); empty installs the
# newest in the archive. amber-ols rides along — Depends: amber-odin keeps
# the two matched, so there is no way to get one without the other.
ARG ODIN_VERSION=
RUN apt-get update \
    && if [ -n "$ODIN_VERSION" ]; then pkg="amber-odin=$ODIN_VERSION"; else pkg="amber-odin"; fi \
    && apt-get install -y --no-install-recommends "$pkg" amber-ols \
    && rm -rf /var/lib/apt/lists/*

# Fail the build here, not at the first consumer's `odin build`.
RUN odin version && command -v ols

# Placed last, after every apt layer, so changing VCS_REF/BUILD_DATE on a
# rebuild busts only this instruction — not the cached install above it.
ARG VCS_REF
ARG BUILD_DATE
LABEL org.opencontainers.image.title="odin-container" \
      org.opencontainers.image.description="Odin compiler and OLS (its language server), from the signed Amber Linux apt archive" \
      org.opencontainers.image.source="https://github.com/Hyperquader-Coders/odin-container" \
      org.opencontainers.image.licenses="BSD-3-Clause" \
      org.opencontainers.image.vendor="Hyperquader" \
      org.opencontainers.image.base.name="ubuntu:24.04" \
      org.opencontainers.image.revision="$VCS_REF" \
      org.opencontainers.image.created="$BUILD_DATE"

WORKDIR /workspace
CMD ["bash"]
