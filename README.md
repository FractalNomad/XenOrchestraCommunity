# XenOrchestraCommunity

Unofficial, community-friendly Xen Orchestra container that builds from the upstream `vatesfr/xen-orchestra` monorepo and explicitly enables the XO6 preview by building `@xen-orchestra/web`.

- Source-built during Docker image build
- XO (classic) served at `/`
- XO6 preview served at `/v6`
- Publish to GHCR on tag push (`v*`) via GitHub Actions

> This project is not affiliated with Vates. Intended for labs/testing. For production, prefer the official XOA appliance.

## Quick start

- Build image locally

```sh
# From repository root
docker compose -f docker/docker-compose.yml build
```

- Run

```sh
docker compose -f docker/docker-compose.yml up -d
# Open http://localhost/ (XO)
# Open http://localhost/v6 (XO6 preview)
```

## How it works

- Multi-stage Dockerfile clones the upstream monorepo and installs workspaces with Yarn (Corepack)
- Runs the monorepo build and then explicitly builds XO6:
  - `yarn run turbo run build --filter @xen-orchestra/web`
- Starts `@xen-orchestra/xo-server` (port 80 by default)

Key files:
- `docker/Dockerfile` — build and runtime image definition
- `docker/docker-compose.yml` — local build/run
- `docker/config.toml` — minimal xo-server config (HTTP on :80)
- `.github/workflows/release-image.yml` — builds and pushes image to GHCR on tag push

## Configuration

- Port: defaults to 80 (see `docker/config.toml`)
- Data: persisted in `xo_data` compose volume (`/var/lib/xo-server/data`)
- Config: persisted in `xo_config` compose volume (`/home/xo/.config/xo-server`)
- Redis: required. The compose file includes a `redis` service by default. In Kubernetes, the Helm chart deploys a Redis service and XO is configured to use it.
- HTTPS: adjust the `[http]` section in `docker/config.toml` and expose 443 in compose

## Customizing the upstream source

Change build args in `docker/docker-compose.yml`:

```yaml
args:
  XO_REPO: https://github.com/vatesfr/xen-orchestra.git
  XO_REF: master # or tags/vX.Y.Z or a commit SHA
```

## Publish to GHCR

- Push a git tag from default branch:

```sh
git tag v1.0.0
git push origin v1.0.0
```

- The workflow pushes these tags (example):
  - `ghcr.io/<owner>/<repo>:v1.0.0`
  - `ghcr.io/<owner>/<repo>:1.0`
  - `ghcr.io/<owner>/<repo>:1`
  - `ghcr.io/<owner>/<repo>:latest`

Pull:

```sh
docker pull ghcr.io/<owner>/<repo>:v1.0.0
```

> Ensure repository/package visibility permits pulling from GHCR.

## Troubleshooting

- Build network hiccups: the Dockerfile increases Yarn HTTP timeouts; re-run build if timeouts occur
- XO6 not visible: ensure image built after the turbo step; visit `/v6`
- Permissions: volumes are owned by `xo` user in the container

## Acknowledgements

- Upstream: https://github.com/vatesfr/xen-orchestra
- Inspiration: https://github.com/ronivay/XenOrchestraInstallerUpdater
