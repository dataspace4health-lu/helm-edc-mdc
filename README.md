# helm-edc-mdc

Helm charts for deploying the **DCA Metadata Capture** stack on Kubernetes.

## Repository structure

```
helm-edc-mdc/
└── components/
    └── dca-metadata-capture/   # Unified Helm chart (app + Keycloak + PostgreSQL)
        ├── Chart.yaml
        ├── values.yaml
        ├── Makefile
        ├── dca-metadata-capture-local-realm.json   # Keycloak realm (ConfigMap)
        └── templates/
            ├── _helpers.tpl
            ├── configmap.yaml          # config.json ConfigMap
            ├── app-secret.yaml         # OIDC / session / SMTP secrets
            ├── postgresql-secret.yaml  # PostgreSQL secret (external DB only)
            ├── deployment.yaml
            ├── service.yaml
            ├── ingress.yaml
            ├── middleware.yaml         # Traefik replacePathRegex middleware
            ├── hpa.yaml
            └── serviceaccount.yaml
```

## Prerequisites

| Tool | Version |
|------|---------|
| Docker | ≥ 20 |
| Helm | ≥ 3.10 |
| kubectl | ≥ 1.24 |
| Local registry | running on `localhost:5432` (or `ds4h-registry:5432`) |
| Traefik | installed as the cluster ingress controller |

---

## 1 – Build & push the Docker image

The app is built with a two-stage Dockerfile (Node 20 → Python 3.12).
The frontend is compiled with Vite and requires a `VITE_BASE_URL` build argument
so that the React Router `basename` and asset paths match the subpath the app is
served under (`/dca` by default).

```bash
# From the dca-metadata-capture source directory
cd /path/to/dca-metadata-capture

docker build -t ds4h-registry:5432/dca-metadata-capture:0.0.0 \
  -f Dockerfile . \
  && docker push ds4h-registry:5432/dca-metadata-capture:0.0.0
```

Or use the Makefile short-cut from the chart directory (builds and pushes automatically):

```bash
cd components/dca-metadata-capture
make docker
```

---

## 2 – Deploy with Helm

### 2.1 Install / upgrade

```bash
cd components/dca-metadata-capture
make install NAMESPACE=default
```

This target:
1. Runs `helm dependency update` (downloads Keycloak 25.2.0 and PostgreSQL 15.2.10 subcharts).
2. Creates the `keycloak-realm` ConfigMap from `dca-metadata-capture-local-realm.json`.
3. Packages and installs the chart.

To install manually:

```bash
helm dependency update .
kubectl create configmap keycloak-realm \
  --from-file=dca-metadata-capture-local-realm.json=./dca-metadata-capture-local-realm.json \
  --namespace default --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install dca-metadata-capture . --namespace default --create-namespace
```

### 2.2 Verify pods

```bash
kubectl get pods -n default
```

Expected output (all `1/1 Running`):

```
NAME                                         READY   STATUS    RESTARTS   AGE
dca-metadata-capture-<hash>                  1/1     Running   0          2m
dca-metadata-capture-keycloak-0              1/1     Running   0          2m
dca-metadata-capture-postgresql-0            1/1     Running   0          2m
dca-metadata-capture-keycloak-postgresql-0   1/1     Running   0          2m
```

### 2.3 Uninstall

```bash
make uninstall NAMESPACE=default
# Remove leftover PVCs if needed:
kubectl delete pvc -l app.kubernetes.io/instance=dca-metadata-capture -n default
```

---

## 3 – Accessing the application

### 3.1 Application URL

The app is served under the `/dca` subpath via a Traefik ingress with TLS:

```
https://dataspace4health.local/dca
```

> The Traefik `replacePathRegex` middleware strips `/dca` before forwarding
> requests to FastAPI, so the application itself sees paths starting with `/`.
> Static assets (CSS/JS) are served directly via the `/assets` ingress path.

**Local development** – add the following entry to `/etc/hosts` if it is not already present:

```
<node-ip>   dataspace4health.local
```

### 3.2 API & interactive docs

| Endpoint | URL |
|----------|-----|
| Health check | `https://dataspace4health.local/dca/api/health` |
| OpenAPI (Swagger UI) | `https://dataspace4health.local/dca/docs` |
| OpenAPI (ReDoc) | `https://dataspace4health.local/dca/redoc` |
| OpenAPI schema (JSON) | `https://dataspace4health.local/dca/openapi.json` |

### 3.3 Keycloak admin console

Keycloak is deployed as a subchart and exposed at:

```
https://dataspace4health.local/iam
```

| Item | Value |
|------|-------|
| Admin URL | `https://dataspace4health.local/iam/admin` |
| Realm | `dca-metadata-capture-local` |
| Admin username | `admin` (see `keycloak.auth.adminUser` in values.yaml) |
| Admin password | set via `secrets.keycloakAdminPassword` |

The realm is pre-configured via a ConfigMap mounted into Keycloak at startup.
It registers the `dca-metadata-capture-local` OIDC client with valid redirect URIs
pointing to `https://dataspace4health.local/dca/*`.

### 3.4 Login flow

1. Open `https://dataspace4health.local/dca` — the app redirects unauthenticated users to Keycloak.
2. Log in with a Keycloak user from the `dca-metadata-capture-local` realm.
3. Keycloak redirects back to `https://dataspace4health.local/dca` with a session cookie.

OIDC endpoints used by the app:

| Endpoint | URL |
|----------|-----|
| Auth | `https://dataspace4health.local/iam/realms/dca-metadata-capture-local/protocol/openid-connect/auth` |
| Token | `https://dataspace4health.local/iam/realms/dca-metadata-capture-local/protocol/openid-connect/token` |
| JWKS | `https://dataspace4health.local/iam/realms/dca-metadata-capture-local/protocol/openid-connect/certs` |
| Logout | `https://dataspace4health.local/iam/realms/dca-metadata-capture-local/protocol/openid-connect/logout` |

---

## 4 – Ingress & routing details

Two Traefik ingress paths are configured for the same backend service:

| Ingress path | Middleware | Purpose |
|---|---|---|
| `/dca` | `replacePathRegex` (strips `/dca`) | Main app — HTML pages and API |
| `/assets` | none | Vite static assets (CSS, JS, fonts) |

The `replacePathRegex` middleware regex:

```
regex:       ^/dca/?(.*)
replacement: /${1}
```

TLS is terminated at Traefik using the `dataspace4health.local` TLS secret.

---

## 5 – Configuration reference

### Key `values.yaml` settings

| Key | Default | Description |
|-----|---------|-------------|
| `image.repository` | `ds4h-registry:5432/dca-metadata-capture` | Image to deploy |
| `image.tag` | `0.0.0` | Image tag |
| `config.appUrl` | `https://dataspace4health.local/dca` | Public URL (used by FastAPI for redirects) |
| `config.environment` | `production` | `production` or `development` |
| `config.loadInitialData` | `False` | Set to `True` **only** on first deployment |
| `config.logLevel` | `INFO` | Log verbosity (`DEBUG`, `INFO`, `WARNING`, `ERROR`) |
| `oidc.clientId` | `dca-metadata-capture-local` | Keycloak client ID |
| `oidc.verify` | `False` | TLS verification for OIDC calls (`False` disables) |
| `ingress.replacePath.regex` | `^/dca/?(.*)` | Traefik path-strip regex |

### Secrets (`secrets:` block)

| Key | Description |
|-----|-------------|
| `secrets.oidcClientSecret` | Keycloak client secret |
| `secrets.sessionSecretKey` | 32-char HMAC key for session signing |
| `secrets.sessionEncryptionKey` | 32-char key for session encryption |
| `secrets.postgresqlPassword` | App DB user password |
| `secrets.keycloakAdminPassword` | Keycloak admin password |

### Environment variables injected into the container

| Variable | Source |
|----------|--------|
| `CONFIG_PATH` | `values.config.configPath` |
| `DATABASE_URL` | auto-constructed from PostgreSQL subchart |
| `ENVIRONMENT` | `values.config.environment` |
| `APP_URL` | `values.config.appUrl` |
| `OPENID_CLIENT_ID` | `values.oidc.clientId` |
| `OPENID_CLIENT_SECRET` | secret |
| `OPENID_AUTH_URL` | `values.oidc.authUrl` |
| `OPENID_TOKEN_URL` | `values.oidc.tokenUrl` |
| `OPENID_JWKS_URL` | `values.oidc.jwksUrl` |
| `OPENID_END_SESSION_URL` | `values.oidc.endSessionUrl` |
| `SESSION_SECRET_KEY` | secret |
| `SESSION_ENCRYPTION_KEY` | secret |
| `SMTP_SERVER` / `SMTP_PORT` / … | `values.smtp` |
| `OTL_URL` | `values.otlp.url` (optional) |
| `CELERY_BROKER_URL` | `values.celery.brokerUrl` (optional) |

---

## 6 – First-time data seeding

On the very first deployment set `config.loadInitialData: "True"` in your
`values.yaml` (or pass `--set config.loadInitialData=True`).
Revert to `"False"` after the first successful start to avoid re-seeding on
every subsequent restart.

---

## 7 – Troubleshooting

### Pods stuck in `Init:Error` or `Init:CrashLoopBackOff`

The init container runs Alembic migrations.  Check its logs:

```bash
kubectl logs -n default <pod-name> -c db-migrate
```

### 404 on `/assets/...`

Happens when the frontend was built **without** `VITE_BASE_URL=/dca`.
Rebuild the Docker image passing the build argument:

```bash
docker build --build-arg VITE_BASE_URL=/dca -t ds4h-registry:5432/dca-metadata-capture:0.0.0 .
```

### Keycloak redirect URI mismatch

Ensure the realm JSON contains `https://dataspace4health.local/dca/*` as a valid
redirect URI, and that `config.appUrl` matches exactly.

### Check ingress routes

```bash
kubectl get ingress -n default dca-metadata-capture -o yaml
kubectl get middleware -n default
```

### Disk pressure on the node

```bash
docker system prune -af --volumes   # free Docker space
kubectl describe node | grep Taint  # check taints
```
