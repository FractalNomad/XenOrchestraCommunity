# --- Builder ---
ARG NODE_IMAGE_BUILDER=node:22-bookworm
ARG NODE_IMAGE_RUNTIME=node:22-bookworm-slim
FROM ${NODE_IMAGE_BUILDER} AS builder

ARG XO_REPO=https://github.com/vatesfr/xen-orchestra.git
ARG XO_REF=master
ARG YARN_SETUP=modern

ENV DEBIAN_FRONTEND=noninteractive \
    COREPACK_ENABLE_DOWNLOAD_PROMPT=0 \
    NODE_OPTIONS=--max_old_space_size=4096 \
    YARN_ENABLE_IMMUTABLE_INSTALLS=false \
    YARN_NPM_REGISTRY_SERVER=https://registry.npmjs.org \
    YARN_HTTP_TIMEOUT=600000

RUN apt-get update && apt-get install -y --no-install-recommends \
    git build-essential python3-minimal ca-certificates curl jq libpng-dev pkg-config \
  && rm -rf /var/lib/apt/lists/*

# Yarn (modern) via Corepack
RUN corepack enable && corepack prepare yarn@stable --activate

WORKDIR /src
RUN git clone --depth 1 --branch ${XO_REF} ${XO_REPO} .
# Install and build the monorepo
RUN yarn install --network-timeout 600000
# Build everything we need (xo-server + XO6 web)
RUN yarn build || true \
 && yarn workspace xo-server build \
 && yarn workspace @xen-orchestra/web build \
 && yarn workspaces foreach --all --topological-dev run build || true

# --- Runtime ---
FROM ${NODE_IMAGE_RUNTIME} AS runtime
ENV DEBIAN_FRONTEND=noninteractive
RUN set -eux; \
    apt-get update; \
    FUSE_PKG=libfuse2; \
    if apt-cache show libfuse2t64 >/dev/null 2>&1; then FUSE_PKG=libfuse2t64; fi; \
    apt-get install -y --no-install-recommends dumb-init openssl ca-certificates "$FUSE_PKG" \
    && rm -rf /var/lib/apt/lists/*

# Non-root user
RUN useradd -ms /bin/bash xo

WORKDIR /opt/xo
# Copy built tree
COPY --from=builder /src /opt/xo

# Healthcheck & config (you can overwrite via ConfigMap in k8s)
# Ensure target dirs exist before copying
RUN mkdir -p /var/lib/xo-server/data /home/xo/.config/xo-server
COPY scripts/healthcheck.sh /opt/xo/healthcheck.sh
COPY config.toml /home/xo/.config/xo-server/config.toml
RUN chmod +x /opt/xo/healthcheck.sh \
 && chown -R xo:xo /opt/xo /var/lib/xo-server /home/xo

USER xo
EXPOSE 8080

# Serve XO6 under /v6 via static mount configured in config.toml
HEALTHCHECK --start-period=60s --interval=30s --timeout=5s --retries=2 CMD /opt/xo/healthcheck.sh
CMD ["dumb-init", "node", "/opt/xo/packages/xo-server/dist/cli.mjs"]
