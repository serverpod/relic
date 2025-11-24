.PHONY: install start version validate-version

# Extract version from command line (e.g., "make version 1.2.3")
# Filter out known targets to get the version argument
VERSION := $(filter-out install start version,$(MAKECMDGOALS))
EXAMPLE_SOURCE_DIR := $(abspath $(CURDIR)/../../example)
VERSIONED_EXAMPLE_DIR := versioned_docs/version-$(VERSION)/_example

install:
	npm install

start:
	npm start

version: validate-version
	npm run docusaurus docs:version $(VERSION)
	@if [ ! -d "versioned_docs/version-$(VERSION)" ]; then \
		echo "Expected directory versioned_docs/version-$(VERSION) was not created"; \
		exit 1; \
	fi
	@if [ ! -d "$(EXAMPLE_SOURCE_DIR)" ]; then \
		echo "Example source directory not found: $(EXAMPLE_SOURCE_DIR)"; \
		exit 1; \
	fi
	rm -rf $(VERSIONED_EXAMPLE_DIR)
	mkdir -p $(dir $(VERSIONED_EXAMPLE_DIR))
	cp -R "$(EXAMPLE_SOURCE_DIR)" "$(VERSIONED_EXAMPLE_DIR)"

validate-version:
	@if [ -z "$(VERSION)" ]; then \
		echo "Usage: make version X.Y.Z"; \
		exit 1; \
	fi

# Create dummy targets for version arguments to prevent Make errors
%:
	@:

