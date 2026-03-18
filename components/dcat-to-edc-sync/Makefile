REGISTRY    ?= localhost:5432
APP         ?= dcat-to-edc-sync
VERSION     ?= 1.0.0
IMAGE       := $(REGISTRY)/$(APP):$(VERSION)
CHART_DIR   := .
HELM_RELEASE ?= $(APP)
NAMESPACE   ?= default

# Path to the sync job source code (relative to this Makefile)
SYNC_SRC    := ../../../dcat-to-edc-sync

# ── Docker ───────────────────────────────────────────────────────────────────

.PHONY: docker-build
docker-build:
	docker build \
		-t $(IMAGE) \
		-f $(SYNC_SRC)/Dockerfile \
		$(SYNC_SRC)

.PHONY: docker-push
docker-push:
	docker push $(IMAGE)

.PHONY: docker
docker: docker-build docker-push

# ── Helm ─────────────────────────────────────────────────────────────────────

.PHONY: helm-deps
helm-deps:
	@echo "No chart dependencies for dcat-to-edc-sync."

.PHONY: build
build: helm-deps
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
	kubectl delete pvc -l app.kubernetes.io/instance=$(HELM_RELEASE) \
		--namespace $(NAMESPACE) 2>/dev/null || true

.PHONY: helm-template
helm-template:
	helm template $(HELM_RELEASE) $(CHART_DIR) --namespace $(NAMESPACE)

.PHONY: helm-lint
helm-lint:
	helm lint $(CHART_DIR)

.PHONY: clean
clean:
	rm -rf helm

# ── Convenience targets ───────────────────────────────────────────────────────

.PHONY: all
all: docker install

.PHONY: reinstall
reinstall: uninstall install

# ── Operations ────────────────────────────────────────────────────────────────

# Force re-sync a single MDC dataset.
# Usage: make resync DATASET=1
DATASET ?= 1
.PHONY: resync
resync:
	@chmod +x resync.sh
	NAMESPACE=$(NAMESPACE) RELEASE=$(HELM_RELEASE) bash resync.sh $(DATASET)

# Print the current sync state (what has been synced and status per asset).
.PHONY: state
state:
	@chmod +x show-state.sh
	NAMESPACE=$(NAMESPACE) RELEASE=$(HELM_RELEASE) bash show-state.sh
