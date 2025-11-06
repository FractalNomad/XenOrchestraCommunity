# Xen Orchestra (community) with XO6 preview build
# Multi-stage build to keep runtime image small

# 1) Builder stage: fetch sources and build
FROM node:20-bullseye AS builder

# Build args to allow pinning specific xen-orchestra ref
ARG XO_REPO=https://github.com/vatesfr/xen-orchestra.git
ARG XO_REF=master

ENV DEBIAN_FRONTEND=noninteractive \
    COREPACK_ENABLE_DOWNLOAD_PROMPT=0 \
    NODE_OPTIONS=--max_old_space_size=4096

# Install build deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    git python3 build-essential ca-certificates curl jq \
    && rm -rf /var/lib/apt/lists/*

# Enable corepack (yarn) and turbo
RUN corepack enable && corepack prepare yarn@stable --activate

# Fetch sources
WORKDIR /build
RUN git clone --depth 1 --branch ${XO_REF} ${XO_REPO} .

# Install workspace deps with network timeouts increased
ENV YARN_ENABLE_IMMUTABLE_INSTALLS=false \
    YARN_NPM_REGISTRY_SERVER=https://registry.npmjs.org \
    YARN_HTTP_TIMEOUT=600000

# Install dependencies; xen-orchestra is a monorepo using yarn workspaces
RUN yarn install --network-timeout 600000

# Build server (xo-server) and XO6 web preview specifically
# Monorepo build, then ensure xo-server and @xen-orchestra/web are built
RUN yarn build || true \
 && yarn workspace xo-server build \
 && (yarn dlx turbo --version || yarn global add turbo) \
 && yarn run turbo run build --filter @xen-orchestra/web

# Ensure all @xen-orchestra/* workspaces are built and linked
RUN yarn workspaces foreach --all --topological-dev run build || true

# 2) Runtime stage
FROM node:20-bullseye-slim AS runtime

ENV DEBIAN_FRONTEND=noninteractive

# Runtime deps: openssl for TLS, tini for init, redis client optional
RUN apt-get update && apt-get install -y --no-install-recommends \
    dumb-init openssl ca-certificates curl libfuse2 \
    && rm -rf /var/lib/apt/lists/*

# Create app user
RUN useradd -ms /bin/bash xo

WORKDIR /opt/xo

# Copy built monorepo
COPY --from=builder /build /opt/xo
COPY scripts /opt/xo/docker/scripts

# Expose default port
EXPOSE 80

# Default config dir and data dir
ENV HOME=/home/xo
RUN mkdir -p /var/lib/xo-server/data /home/xo/.config/xo-server \
    && chown -R xo:xo /opt/xo /var/lib/xo-server /home/xo

# Provide a sensible default config.toml (http on :80)
COPY config.toml /home/xo/.config/xo-server/config.toml
RUN chown xo:xo /home/xo/.config/xo-server/config.toml

USER xo

# Start xo-server directly from built dist; XO6 preview is served at /v6
CMD ["dumb-init", "node", "/opt/xo/packages/xo-server/dist/cli.mjs"]
