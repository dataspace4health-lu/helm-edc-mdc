SUBDIRS     := $(wildcard components/*/.)
CURRENT_DIR := dca-metadata-capture
NAMESPACE   ?= default

.PHONY: all build install reinstall uninstall clean docker lint template $(SUBDIRS)

# ── Aggregated targets (delegate to all component sub-makes) ─────────────────

all: docker install

# Propagate the current goal down to every component subdirectory
$(SUBDIRS):
	$(MAKE) -C $@ $(MAKECMDGOALS) NAMESPACE=$(NAMESPACE)

# ── Docker ───────────────────────────────────────────────────────────────────

docker: $(SUBDIRS)
	@echo "Docker image(s) built and pushed for all components."

# ── Helm ─────────────────────────────────────────────────────────────────────

build: $(SUBDIRS)
	@echo "All component charts packaged."

install:
ifeq ($(strip $(NAMESPACE)),)
	$(eval NAMESPACE := default)
	@echo "NAMESPACE is not set, using default. Usage: make install NAMESPACE=<ns>"
endif
	@echo "Installing all components into namespace '$(NAMESPACE)'"
	$(MAKE) -C components/$(CURRENT_DIR) install NAMESPACE=$(NAMESPACE)

reinstall:
ifeq ($(strip $(NAMESPACE)),)
	$(eval NAMESPACE := default)
endif
	@echo "Re-installing all components in namespace '$(NAMESPACE)'"
	$(MAKE) -C components/$(CURRENT_DIR) reinstall NAMESPACE=$(NAMESPACE)

uninstall:
ifeq ($(strip $(NAMESPACE)),)
	$(eval NAMESPACE := default)
	@echo "NAMESPACE is not set, using default. Usage: make uninstall NAMESPACE=<ns>"
endif
	@echo "Uninstalling all components from namespace '$(NAMESPACE)'"
	$(MAKE) -C components/$(CURRENT_DIR) uninstall NAMESPACE=$(NAMESPACE)

# ── Lint & template rendering ─────────────────────────────────────────────────

lint: $(SUBDIRS)
	@echo "All component charts linted."

template:
	$(MAKE) -C components/$(CURRENT_DIR) helm-template NAMESPACE=$(NAMESPACE)

# ── Cleanup ───────────────────────────────────────────────────────────────────

clean: $(SUBDIRS)
	@echo "All component build artefacts removed."
