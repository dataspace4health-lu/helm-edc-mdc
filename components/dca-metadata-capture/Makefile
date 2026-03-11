REGISTRY    ?= localhost:5432
APP         ?= dca-metadata-capture
VERSION     ?= 2.0.0
IMAGE       := $(REGISTRY)/$(APP):$(VERSION)
CHART_DIR   := .
HELM_RELEASE ?= $(APP)
NAMESPACE   ?= default

# ── Docker ───────────────────────────────────────────────────────────────────

.PHONY: docker-build
docker-build:
	docker build \
		-t $(IMAGE) \
		-f ../../../dca-metadata-capture/Dockerfile \
		../../../dca-metadata-capture

.PHONY: docker-push
docker-push:
	docker push $(IMAGE)

.PHONY: docker
docker: docker-build docker-push

# ── Helm ─────────────────────────────────────────────────────────────────────

.PHONY: helm-deps
helm-deps:
	helm dependency update $(CHART_DIR)

.PHONY: build
build: helm-deps
	# realm JSON is too large to embed in the chart — create ConfigMap separately
	kubectl create configmap keycloak-realm \
		--from-file=dca-metadata-capture-local-realm.json=$(CHART_DIR)/dca-metadata-capture-local-realm.json \
		--namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	mkdir -p helm
	helm package $(CHART_DIR) -d helm

.PHONY: install
install: build
	helm upgrade --install $(HELM_RELEASE) helm/*.tgz \
		--namespace $(NAMESPACE) \
		--create-namespace

.PHONY: uninstall
uninstall:
	helm uninstall $(HELM_RELEASE) --namespace $(NAMESPACE) 2>/dev/null || true
	kubectl delete configmap keycloak-realm --namespace $(NAMESPACE) 2>/dev/null || true
	kubectl delete pvc -l app.kubernetes.io/instance=$(HELM_RELEASE) \
		--namespace $(NAMESPACE) 2>/dev/null || true

.PHONY: helm-template
helm-template: helm-deps
	helm template $(HELM_RELEASE) $(CHART_DIR) --namespace $(NAMESPACE)

.PHONY: helm-lint
helm-lint: helm-deps
	helm lint $(CHART_DIR)

.PHONY: clean
clean:
	rm -rf charts helm

# ── Convenience targets ───────────────────────────────────────────────────────

.PHONY: all
all: docker install

.PHONY: reinstall
reinstall: uninstall install
