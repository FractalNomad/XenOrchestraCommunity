# Xen Orchestra (community) with XO6 preview build
# Multi-stage build to keep runtime image small

# 1) Builder stage: fetch sources and build
# Global ARG declarations (must precede any FROM to be usable in FROM)
# Allow selecting Node images for builder/runtime (legacy compatibility)
ARG NODE_IMAGE_BUILDER=node:22-trixie
ARG NODE_IMAGE_RUNTIME=node:22-trixie-slim
FROM ${NODE_IMAGE_BUILDER} AS builder

# Build args to allow pinning specific xen-orchestra ref
ARG XO_REPO=https://github.com/vatesfr/xen-orchestra.git
ARG XO_REF=master
ARG YARN_SETUP=modern  # modern | classic
ARG NEED_PY2=false     # true to install python2 for legacy node-gyp

ENV DEBIAN_FRONTEND=noninteractive \
    COREPACK_ENABLE_DOWNLOAD_PROMPT=0 \
    NODE_OPTIONS=--max_old_space_size=4096

# Install build deps (conditionally add python2 for legacy)
RUN set -eux; \
        # Workaround for EOL Debian buster: switch to archive mirrors if detected
        if grep -Eqs 'VERSION_CODENAME=buster' /etc/os-release || grep -qs 'buster' /etc/apt/sources.list; then \
            sed -i -e 's|deb.debian.org|archive.debian.org|g' \
                         -e 's|security.debian.org/debian-security|archive.debian.org/debian-security|g' /etc/apt/sources.list || true; \
            if ls /etc/apt/sources.list.d/*.list >/dev/null 2>&1; then \
                sed -i -e 's|deb.debian.org|archive.debian.org|g' \
                             -e 's|security.debian.org/debian-security|archive.debian.org/debian-security|g' /etc/apt/sources.list.d/*.list || true; \
            fi; \
            echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid-until; \
        fi; \
        apt-get update && apt-get install -y --no-install-recommends \
            git build-essential python3-minimal ca-certificates curl jq libpng-dev pkg-config fuse \
            && if [ "$NEED_PY2" = "true" ]; then apt-get install -y python; fi \
            && rm -rf /var/lib/apt/lists/*

# Yarn setup: use Yarn classic for older upstream, otherwise latest via Corepack
# Avoid EEXIST if yarn already preinstalled in base image
RUN if [ "$YARN_SETUP" = "classic" ]; then \
            if command -v yarn >/dev/null 2>&1; then \
                yarn --version; \
            else \
                npm i -g yarn@1.22.22; \
            fi; \
        else \
            corepack enable && corepack prepare yarn@stable --activate; \
        fi

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

# Symlink all plugins into xo-server/node_modules (except excluded ones)
RUN find /build/packages/ -maxdepth 1 -mindepth 1 \
    -not -name "xo-server" -not -name "xo-web" -not -name "xo-server-cloud" \
    -not -name "xo-server-test" -not -name "xo-server-test-plugin" \
    -exec ln -s {} /build/packages/xo-server/node_modules \;

# 2) Runtime stage
# Use matching Node major; ARG declared globally above
FROM ${NODE_IMAGE_RUNTIME} AS runtime

ENV DEBIAN_FRONTEND=noninteractive

# Runtime deps: openssl for TLS, tini for init, redis client optional
RUN set -eux; \
        # Workaround for EOL Debian buster: switch to archive mirrors if detected
        if grep -Eqs 'VERSION_CODENAME=buster' /etc/os-release || grep -qs 'buster' /etc/apt/sources.list; then \
            sed -i -e 's|deb.debian.org|archive.debian.org|g' \
                         -e 's|security.debian.org/debian-security|archive.debian.org/debian-security|g' /etc/apt/sources.list || true; \
            if ls /etc/apt/sources.list.d/*.list >/dev/null 2>&1; then \
                sed -i -e 's|deb.debian.org|archive.debian.org|g' \
                             -e 's|security.debian.org/debian-security|archive.debian.org/debian-security|g' /etc/apt/sources.list.d/*.list || true; \
            fi; \
            echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid-until; \
        fi; \
        apt-get update; \
        # Select correct fuse runtime package depending on Debian release
        FUSE_PKG=libfuse2; \
        if apt-cache show libfuse2t64 >/dev/null 2>&1; then FUSE_PKG=libfuse2t64; fi; \
        # Install only minimal, widely-available runtime deps for XO server
        apt-get install -y --no-install-recommends \
            dumb-init openssl ca-certificates curl "$FUSE_PKG" \
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
HEALTHCHECK --start-period=1m --interval=30s --timeout=5s --retries=2 CMD /opt/xo/docker/scripts/healthcheck.sh
CMD ["dumb-init", "node", "/opt/xo/packages/xo-server/dist/cli.mjs"]
