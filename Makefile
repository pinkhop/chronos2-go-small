# chronos2-go-small — formatting, analysis, builds, and checks on the embedded
# weights and on the module's size.
#
# `make help` lists every public target alphabetically with its one-line
# description. The listing is generated from the `## target: description`
# comments below, so a new target documents itself by carrying one.
#
# Go commands take the workspace from the GOWORK environment variable, which
# make passes through unchanged; set it to build against an unpublished
# chronos2-go checkout (see AGENTS.md). Nothing here names a workspace.
#
# Every target is phony; the Go toolchain already does its own staleness
# tracking. Every tool a target runs comes from PATH. The repository's mise.toml
# pins each one, together with the Go toolchain, and `mise install` provisions
# them all.


###############################################################################
# MODULE SETTINGS

APP := chronos2-go-small


###############################################################################
# COMMON SETTINGS

# The directory holding config.json, manifest.json, and the safetensors shards.
WEIGHTS_DIR := weights

# The ceiling Go places on a module, in bytes, applied twice: to the zip that
# `git archive` produces for the module's repository, and to the module zip's
# total uncompressed size. Both limits are 500 MiB.
MODULE_SIZE_LIMIT := 524288000

# Every hand-written Go file Git does not ignore, including new files not yet
# added.
GO_FILES = git ls-files --cached --others --exclude-standard '*.go'

.DEFAULT_GOAL := help
.PHONY: build check check-size format help lint security security-gosec security-govulncheck verify-weights


###############################################################################
# TARGETS

## build: compile the package, which embeds every shard
build:
	go build ./...

## check: verify the weights against the manifest, then the module's size against Go's limits
check: verify-weights check-size

## check-size: check the working tree, as it would be committed, against Go's module size limits
#
# Go downloads a module at a repository root with `git archive`, so both the
# archive of the whole tree and the sum of its file sizes must stay within
# MODULE_SIZE_LIMIT. The tree is built in a temporary index seeded from the
# real one, so tracked files stay tracked and ignored files stay out; the real
# index, HEAD, and every ref are left untouched. `git add` does write the new
# blobs to the object database, where a later commit reuses them.
check-size:
	@set -e; \
	scratch=$$(mktemp -d); trap 'rm -rf "$$scratch"' EXIT; \
	index=$$(git rev-parse --git-path index); \
	if [ -f "$$index" ]; then cp "$$index" "$$scratch/index"; fi; \
	export GIT_INDEX_FILE="$$scratch/index"; \
	git add -A; \
	tree=$$(git write-tree); \
	archive=$$(git archive --format=zip "$$tree" | wc -c | tr -d ' '); \
	files=$$(git ls-tree -r -l "$$tree" | awk '$$2 == "blob" { total += $$4 } END { printf "%d", total }'); \
	status=0; \
	for measure in "archive zip:$$archive" "uncompressed files:$$files"; do \
		label=$${measure%%:*}; bytes=$${measure##*:}; \
		headroom=$$(( $(MODULE_SIZE_LIMIT) - bytes )); \
		awk -v label="$$label" -v bytes="$$bytes" -v headroom="$$headroom" 'BEGIN { \
			printf "%-20s %11d bytes (%6.1f MiB), headroom %11d bytes (%6.1f MiB)\n", \
				label, bytes, bytes / 1048576, headroom, headroom / 1048576 }'; \
		if [ "$$bytes" -gt $(MODULE_SIZE_LIMIT) ]; then \
			echo "$$label exceeds the limit of $(MODULE_SIZE_LIMIT) bytes"; status=1; \
		fi; \
	done; \
	exit $$status

## format: rewrite the hand-written Go files with goimports, then gofumpt
format:
	@files=$$($(GO_FILES)); \
	if [ -n "$$files" ]; then goimports -w $$files && gofumpt -w $$files; fi

## help: list the available targets
help:
	@echo "$(APP) — available targets:"
	@echo
	@grep -hE '^## [a-z0-9-]+:' $(MAKEFILE_LIST) \
		| sed -e 's/^## //' \
		| awk -F': ' '{ printf "%s\t%s\n", $$1, $$2 }' \
		| sort \
		| awk -F'\t' '{ printf "  %-22s %s\n", $$1, $$2 }'

## lint: check formatting, run the analyzers, then check spelling
#
# The formatters run in check mode, so lint never mutates the tree. errcheck's
# -blank is deliberately not set, because a justified discard is written
# `_ = f()`.
lint:
	@files=$$($(GO_FILES)); \
	for formatter in goimports gofumpt; do \
		echo "==> $$formatter"; \
		offenders=$$([ -z "$$files" ] || $$formatter -l $$files); \
		if [ -n "$$offenders" ]; then \
			echo "not $$formatter-formatted:"; echo "$$offenders"; \
			echo "run: make format"; exit 1; \
		fi; \
	done
	@echo "==> go vet"
	@go vet ./...
	@echo "==> staticcheck"
	@staticcheck ./...
	@echo "==> errcheck"
	@errcheck -asserts ./...
	@echo "==> ineffassign"
	@ineffassign ./...
	@echo "==> misspell"
	@files=$$($(GO_FILES)); [ -z "$$files" ] || misspell -locale US -source=go -error $$files
	@echo "==> typos"
	@typos --locale en-us

## security: run every security scanner — gosec, then govulncheck
security: security-gosec security-govulncheck

## security-gosec: scan the module for insecure code patterns
security-gosec:
	@echo "==> gosec"
	@gosec -quiet -exclude-generated ./...

## security-govulncheck: check the module's dependencies against the Go vulnerability database
#
# Not hermetic: it needs network access and consults a database that changes
# independently of this repository.
security-govulncheck:
	@echo "==> govulncheck"
	@govulncheck ./...

## verify-weights: check config.json and every shard against weights/manifest.json
#
# Checks the config's SHA-256; each listed shard's byte count, SHA-256, and size
# against max_shard_bytes; and that the safetensors files on disk are exactly
# the shards the manifest lists, each listed once.
verify-weights:
	@set -e; cd $(WEIGHTS_DIR); \
	status=0; \
	expected=$$(jq -er '.config_sha256' manifest.json); \
	actual=$$(shasum -a 256 config.json | cut -d ' ' -f 1); \
	if [ "$$actual" = "$$expected" ]; then echo "ok    config.json"; \
	else echo "FAIL  config.json: sha256 $$actual, manifest $$expected"; status=1; fi; \
	duplicates=$$(jq -er '.shards[].file' manifest.json | sort | uniq -d); \
	if [ -n "$$duplicates" ]; then echo "FAIL  listed more than once:"; echo "$$duplicates"; status=1; fi; \
	listed=$$(jq -er '.shards[].file' manifest.json | sort -u); \
	present=$$(find . -maxdepth 1 -name '*.safetensors' -exec basename {} \; | sort); \
	for file in $$listed; do \
		echo "$$present" | grep -qxF "$$file" || { echo "FAIL  $$file: listed but not on disk"; status=1; }; \
	done; \
	for file in $$present; do \
		echo "$$listed" | grep -qxF "$$file" || { echo "FAIL  $$file: on disk but not listed"; status=1; }; \
	done; \
	max=$$(jq -er '.max_shard_bytes' manifest.json); \
	jq -er '.shards[] | "\(.file) \(.bytes) \(.sha256)"' manifest.json | { \
		while read -r file bytes sha; do \
			[ -f "$$file" ] || continue; \
			size=$$(wc -c < "$$file" | tr -d ' '); \
			digest=$$(shasum -a 256 "$$file" | cut -d ' ' -f 1); \
			problems=""; \
			[ "$$size" = "$$bytes" ] || problems="$$problems size $$size, manifest $$bytes;"; \
			[ "$$size" -le "$$max" ] || problems="$$problems size $$size over max_shard_bytes $$max;"; \
			[ "$$digest" = "$$sha" ] || problems="$$problems sha256 $$digest, manifest $$sha;"; \
			if [ -z "$$problems" ]; then echo "ok    $$file"; \
			else echo "FAIL  $$file:$$problems"; status=1; fi; \
		done; \
		exit $$status; \
	}
