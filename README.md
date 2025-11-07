# XenOrchestraCommunity

Unofficial, community-friendly Xen Orchestra container that builds from the upstream `vatesfr/xen-orchestra` monorepo and explicitly enables the XO6 preview by building `@xen-orchestra/web`.

- Source-built during Docker image build
- XO (classic) served at `/`
- XO6 preview served at `/v6`
- Publish Docker images to GHCR and Helm charts to GitHub Pages on tag push (`v*`)
- Ready-to-use Helm chart for Kubernetes deployments

> This project is not affiliated with Vates. Intended for labs/testing. For production, prefer the official XOA appliance.

## Installation Options

### Option 1: Kubernetes (Helm Chart) - Recommended

Add the Helm repository:
```bash
helm repo add xen-orchestra-community https://fractalnomad.github.io/XenOrchestraCommunity/
helm repo update
```

Install with default values:
```bash
helm install xo xen-orchestra-community/xen-orchestra-community \
  --namespace xo --create-namespace
```

Custom installation with your own values:
```bash
helm install xo xen-orchestra-community/xen-orchestra-community \
  --namespace xo --create-namespace \
  -f your-values.yaml
```

**Key Helm chart features:**
- Includes Redis deployment and service
- Configurable ingress with TLS support
- Persistent storage for XO data and config
- Resource limits and requests
- Health checks and probes
- Service account and security contexts

### Option 2: Docker Compose

For local development or single-node deployments:

Build and run locally:
```bash
# From repository root
docker compose -f docker/docker-compose.yml build
docker compose -f docker/docker-compose.yml up -d

# Access the application
# XO (classic): http://localhost/
# XO6 preview: http://localhost/v6
```

Or use the published image:
```bash
# Pull from GitHub Container Registry
docker pull ghcr.io/fractalnomad/xenorchestracommunity:latest
```

## Helm Chart Configuration

### Quick Start Values

**Basic deployment:**
```yaml
# values.yaml
ingress:
  enabled: true
  hosts:
    - host: xo.example.com
      paths:
        - path: /
          pathType: Prefix

persistence:
  enabled: true
  size: 10Gi
```

**Production-ready with TLS:**
```yaml
# production-values.yaml
replicaCount: 2

ingress:
  enabled: true
  className: "nginx"
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
  hosts:
    - host: xo.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: xo-tls
      hosts:
        - xo.example.com

persistence:
  enabled: true
  size: 50Gi
  storageClass: "fast-ssd"

resources:
  requests:
    cpu: 500m
    memory: 1Gi
  limits:
    cpu: 2
    memory: 4Gi

redis:
  persistence:
    enabled: true
    size: 5Gi

### XO configuration via values.yaml

You can configure XO server options that are rendered into `config.toml` by the chart:

```yaml
http:
  hostname: "xo.example.com"   # optional bind hostname
  redirectToHttps: true         # enable 80->443 redirect when HTTPS is enabled
  https:
    enabled: true
    cert: "/etc/ssl/xo/tls.crt"  # mount a Secret at this path
    key: "/etc/ssl/xo/tls.key"
    autoCert: false
    acme:
      enabled: false
      domain: "xo.example.com"
      email: "admin@example.com"

logs:
  syslog:
    enabled: true
    target: "udp://syslog.example.com:514"

tasks:
  persistLogs: false  # set false to mitigate task log store errors in some upstream builds
```

See `charts/xen-orchestra-community/values.yaml` for all options.
```

### Chart Values Reference

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of XO pods | `1` |
| `image.repository` | Container image repository | `ghcr.io/fractalnomad/xenorchestracommunity` |
| `image.tag` | Container image tag | `"latest"` |
| `persistence.enabled` | Enable persistent storage | `true` |
| `persistence.size` | Storage size for XO data | `20Gi` |
| `ingress.enabled` | Enable ingress | `false` |
| `ingress.hosts` | Ingress hostnames | `[]` |
| `redis.enabled` | Deploy Redis | `true` |
| `redis.persistence.enabled` | Redis persistent storage | `true` |

See the full [values.yaml](./charts/xen-orchestra-community/values.yaml) for all configuration options.

Note on Helm chart ports and annotations:

- By default, the pod listens on port 8080 and the Service exposes port 80 mapped to the container's 8080.
- Override the container port with `containerPort` in values.
- Add pod-level annotations (e.g., Linkerd) via `podAnnotations` in values.

## Quick Start Guide

## How it works

- Multi-stage Dockerfile clones the upstream monorepo and installs workspaces with Yarn (Corepack)
- Runs the monorepo build and then explicitly builds XO6:
  - `yarn run turbo run build --filter @xen-orchestra/web`
- Starts `@xen-orchestra/xo-server` (container listens on 8080 by default; Docker maps host 80 -> 8080; Helm Service exposes 80 -> 8080)

Key files:
- `docker/Dockerfile` — build and runtime image definition
- `docker/docker-compose.yml` — local build/run
- `docker/config.toml` — minimal xo-server config (HTTP on :8080)
- `.github/workflows/release-image.yml` — builds and pushes image to GHCR on tag push

## Configuration

- Port:
  - Docker: container listens on 8080; Compose maps host 80 -> 8080 (see `docker/config.toml` and `docker/docker-compose.yml`)
  - Helm: container defaults to 8080; Service exposes 80 -> 8080
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

## Releases and Versioning

This project follows semantic versioning and publishes both Docker images and Helm charts on git tag pushes.

### Creating a Release

Push a version tag from the main branch:
```bash
git checkout main
git pull
git tag v1.2.3
git push origin v1.2.3
```

This automatically:
1. **Builds and publishes Docker image** to GHCR with tags:
   - `ghcr.io/fractalnomad/xenorchestracommunity:v1.2.3`
   - `ghcr.io/fractalnomad/xenorchestracommunity:1.2.3`
   - `ghcr.io/fractalnomad/xenorchestracommunity:1.2`
   - `ghcr.io/fractalnomad/xenorchestracommunity:1`
   - `ghcr.io/fractalnomad/xenorchestracommunity:latest`

2. **Updates Helm chart version** automatically to match the tag (e.g., `1.2.3`)

3. **Publishes Helm chart** to GitHub Pages:
   - Creates GitHub release with chart package
   - Updates https://fractalnomad.github.io/XenOrchestraCommunity/index.yaml

4. **Updates documentation** on GitHub Pages with current chart info

### Using Published Releases

**Docker:**
```bash
docker pull ghcr.io/fractalnomad/xenorchestracommunity:v1.2.3
```

**Helm:**
```bash
helm repo add xen-orchestra-community https://fractalnomad.github.io/XenOrchestraCommunity/
helm repo update
helm install xo xen-orchestra-community/xen-orchestra-community --version 1.2.3
```

> **Note:** Chart versions automatically sync with git tags. No manual Chart.yaml updates needed!

## Troubleshooting

### Docker/Build Issues
- **Build network hiccups:** The Dockerfile increases Yarn HTTP timeouts; re-run build if timeouts occur
- **XO6 not visible:** Ensure image built after the turbo step; visit `/v6`
- **Permissions:** Volumes are owned by `xo` user in the container

### Helm Chart Issues
- **Pod not starting:** Check logs with `kubectl logs -l app.kubernetes.io/name=xen-orchestra-community`
- **Redis connection:** Ensure Redis service is running: `kubectl get svc -l app=redis`
- **Storage issues:** Verify PVC creation: `kubectl get pvc`
- **Ingress not working:** Check ingress controller and DNS: `kubectl get ingress`

### Common Solutions
```bash
# Check pod status
kubectl get pods -n xo

# View logs
kubectl logs -n xo deployment/xo-xen-orchestra-community

# Debug with shell access
kubectl exec -n xo -it deployment/xo-xen-orchestra-community -- /bin/bash

# Restart deployment
kubectl rollout restart -n xo deployment/xo-xen-orchestra-community

# Check all resources
kubectl get all -n xo
```

### Performance Tuning
- **Memory:** Increase `resources.limits.memory` for large environments
- **CPU:** Adjust `resources.requests.cpu` based on usage
- **Storage:** Use fast storage classes for better performance
- **Redis:** Enable Redis persistence for production deployments

## Acknowledgements

- Upstream: https://github.com/vatesfr/xen-orchestra
- Inspiration: https://github.com/ronivay/XenOrchestraInstallerUpdater
