# Xen Orchestra Community (XO6 preview)

This Docker setup builds Xen Orchestra from source and enables the XO6 preview UI by explicitly building `@xen-orchestra/web` with Turbo.

What you get:
- Monorepo build from `vatesfr/xen-orchestra` (default: master)
- XO server listening on port 80
- XO6 preview built and available under `/v6`

## Build the image

```sh
# Build locally (uses docker-compose and the Dockerfile)
docker compose -f docker/docker-compose.yml build
```

## Run

```sh
docker compose -f docker/docker-compose.yml up -d
# Open http://localhost/ (XO), and http://localhost/v6 (XO6 preview)
```

## Customize source

You can change the build args in `docker/docker-compose.yml`:
- `XO_REPO`: Git URL for the Xen Orchestra monorepo
- `XO_REF`: Branch, tag, or commit to build

Example:
```yaml
args:
  XO_REPO: https://github.com/vatesfr/xen-orchestra.git
  XO_REF: tags/v5.139.0
```

## Notes
- This uses Node 20, yarn via Corepack, and Turbo to build `@xen-orchestra/web`.
- Redis is required. The included `docker-compose.yml` starts a `redis` service and `docker/config.toml` points XO to `redis://redis:6379/0`.
- Certificates: replace with HTTPS config in `config.toml` and expose 443 as needed.

## Publish to GHCR

This repo includes a GitHub Actions workflow that builds and pushes the Docker image to GitHub Container Registry when a tag is pushed (matching `v*`).

Steps:
1. Ensure the repository visibility and Packages permissions allow GHCR publishing.
2. Push a semver tag, e.g. `v1.0.0`.

The workflow will produce these tags (examples):
- `ghcr.io/<owner>/<repo>:v1.0.0`
- `ghcr.io/<owner>/<repo>:1.0`
- `ghcr.io/<owner>/<repo>:1`
- `ghcr.io/<owner>/<repo>:latest`

You can pull with:

```sh
docker pull ghcr.io/<owner>/<repo>:v1.0.0
```
