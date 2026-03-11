# DCA Metadata Capture Helm Chart (Unified with Keycloak)

This Helm chart deploys the DCA Metadata Capture application (FastAPI backend + Vite frontend) and a Keycloak instance for OIDC authentication, using a single unified chart structure.

## Features
- Deploys DCA Metadata Capture app and Keycloak as subchart
- Handles Keycloak realm import via ConfigMap
- Unified Makefile for build, install, uninstall
- Reference structure based on fcat-service

## Usage

### Build and Install
```sh
make install NAMESPACE=<your-namespace>
```

### Uninstall
```sh
make uninstall NAMESPACE=<your-namespace>
```

### Chart Structure
- `templates/keycloak/`: Keycloak ConfigMap and helpers
- `dca-metadata-capture-local-realm.json`: Keycloak realm definition
- `values.yaml`: Unified values for app and Keycloak
- `Makefile`: Unified build/install/uninstall logic

## Configuration
See `values.yaml` for all configurable options, including Keycloak settings under the `keycloak:` section.

## Notes
- The Keycloak realm JSON is managed as a Kubernetes ConfigMap due to its size.
- The chart expects a working Kubernetes cluster and Helm 3.x.

---

For more details, see the comments in `values.yaml` and the Makefile.
