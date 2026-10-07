IMAGE ?= hyperquader/odin-container
ODIN_VERSION ?=
BRANCH ?= main
REMOTE ?= origin
ROOT_COMMIT_MSG ?= Initial odin-container

.PHONY: build check check-no-leak tag deploy ci lint push force-push clean run check-no-agent-files help

# targets: no test (no code of its own; `check` builds the image and runs its packaged binaries)

# Builds :build from the Dockerfile. ODIN_VERSION pins the amber-odin
# package version; empty tracks the newest in the archive. VCS_REF/BUILD_DATE
# feed the image's org.opencontainers.image.* labels.
VCS_REF := $(shell git rev-parse --short HEAD 2>/dev/null || echo unknown)
BUILD_DATE := $(shell date -u +%Y-%m-%dT%H:%M:%SZ)

# --pull --no-cache: the apt layer would otherwise be reused from an earlier
# build and ship whatever odin the archive had then.
build: ## build the image as :build
	docker build --pull --no-cache $(if $(ODIN_VERSION),--build-arg ODIN_VERSION=$(ODIN_VERSION)) \
		--build-arg VCS_REF=$(VCS_REF) \
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		-t $(IMAGE):build .

# Speaks to the real packaged binaries rather than trusting the build log.
check: build check-no-leak ## build the image, prove nothing leaked in, run its odin and ols
	docker run --rm $(IMAGE):build sh -c 'odin version && command -v ols >/dev/null && echo "check: OK"'

# Nothing from this directory belongs in the image: it is built from apt
# alone and .dockerignore admits only the Dockerfile. Three ways the working
# tree could still get in, each checked against the built image itself:
#   1. a COPY/ADD layer (the base image's own rootfs ADD is the one allowed);
#   2. repo, agent or credential paths present in the filesystem;
#   3. a Docker Hub token or local path baked into any file, env or label,
#      the packaged odin and ols binaries included. Upstream's odin is a static
#      Alpine build and carries libgcc's paths under /home/buildozer/, Alpine's
#      public package builder; that one name is allowed, nothing else.
# Paths under /usr/lib/amber-odin are Odin's bundled source tree (its own
# README.md and .gitignore files) and are dpkg-owned, so they are excluded.
check-no-leak: ## refuse repo, agent or credential leftovers in the image
	@copies=$$(docker history --no-trunc --format '{{.CreatedBy}}' $(IMAGE):build \
		| grep -Ei '(^|[[:space:]])(COPY|ADD) ' | grep -v '#(nop) ADD file:' || true); \
	if [ -n "$$copies" ]; then \
		echo "check-no-leak: image has COPY/ADD layers beyond the base rootfs:"; \
		echo "$$copies" | sed 's/^/  /'; exit 2; \
	fi
	@paths=$$(docker run --rm $(IMAGE):build sh -c \
		'find / -xdev \( -path /proc -o -path /sys -o -path /usr/lib/amber-odin \) -prune -o -print 2>/dev/null' \
		| grep -E '(^|/)(\.git|\.gitignore|\.dockerignore|Dockerfile|Makefile|MoSCoW\.md|docs|diags|\.claude|\.claude-amber|\.mcp\.json|\.docker|\.crane-config|\.credentials\.json|image\.tar|\.gnupg|\.ssh)$$' || true); \
	if [ -n "$$paths" ]; then \
		echo "check-no-leak: repo, agent or credential paths present in image:"; \
		echo "$$paths" | sed 's/^/  /'; exit 2; \
	fi
	@meta=$$(docker inspect -f '{{json .Config.Env}} {{json .Config.Labels}}' $(IMAGE):build \
		| grep -E 'dckr_pat_|DOCKER_TOKEN|/home/' || true); \
	if [ -n "$$meta" ]; then \
		echo "check-no-leak: token or local path in image env/labels:"; \
		echo "  $$meta"; exit 2; \
	fi
	@strings=$$(docker run --rm $(IMAGE):build sh -c \
		'grep -rIl -E "dckr_pat_|DOCKER_TOKEN|crane-config|/home/[a-z]+/" / --exclude-dir=proc --exclude-dir=sys --exclude-dir=dev --exclude-dir=amber-odin 2>/dev/null; \
		 for f in /usr/bin/odin /usr/bin/ols $$(find /usr/lib/amber-odin /usr/lib/amber-ols -type f \( -name "*.so*" -o -perm -u+x \) 2>/dev/null); do \
			[ -f "$$f" ] && grep -aoE "dckr_pat_|/home/[a-z]+/|/tmp/[^ ]*amber" "$$(readlink -f "$$f")" | grep -qv "^/home/buildozer/$$" && echo "$$f"; \
		 done' | sort -u || true); \
	if [ -n "$$strings" ]; then \
		echo "check-no-leak: token or local path found inside image files:"; \
		echo "$$strings" | sed 's/^/  /'; exit 2; \
	fi
	@echo "check-no-leak: OK"

# Tags :build as the odin version it actually carries plus :latest, so a
# pulled image says what it contains instead of just "the newest push".
# `odin version` prints e.g. "odin version dev-2026-08-nightly:902106f" —
# the last field, with ':' swapped for '-' since Docker tags forbid it.
tag: check ## tag :build as its odin version and :latest
	@mkdir -p build
	@ver="$$(docker run --rm $(IMAGE):build odin version | awk '{print $$NF}' | tr ':' '-')"; \
	test -n "$$ver" || { echo "tag: could not read odin version from image"; exit 1; }; \
	echo "$$ver" > build/version; \
	docker tag $(IMAGE):build "$(IMAGE):$$ver"; \
	docker tag $(IMAGE):build $(IMAGE):latest; \
	echo "tagged $(IMAGE):$$ver and $(IMAGE):latest"

CRANE_CONFIG := build/.crane-config

# Publishes both tags to Docker Hub via crane, not `docker push` — pushing
# from a docker-save tarball with crane's own auth means `deploy` never runs
# `docker login`, which would mutate ~/.docker/config.json system-wide.
# Credentials live only under $(CRANE_CONFIG) for the duration of this
# target and are removed at the end, win or lose. Never push :build
# directly — tag derives the real version tag first so latest and the pin
# move together.
# The token is read from the environment by the shell, never expanded by make:
# a make expansion would put it on the command line, where ps shows it.
deploy: tag ## publish both tags to Docker Hub (DOCKER_USER, DOCKER_TOKEN)
	@test -n "$$DOCKER_TOKEN" || { echo "DOCKER_TOKEN not set"; exit 1; }
	@test -n "$$DOCKER_USER" || { echo "DOCKER_USER not set"; exit 1; }
	@ver="$$(cat build/version)"; \
	rm -rf $(CRANE_CONFIG); mkdir -p $(CRANE_CONFIG); \
	trap 'rm -rf $(CRANE_CONFIG) build/image.tar' EXIT; \
	docker save $(IMAGE):build -o build/image.tar; \
	printf '%s' "$$DOCKER_TOKEN" | DOCKER_CONFIG=$(CRANE_CONFIG) crane auth login index.docker.io -u "$$DOCKER_USER" --password-stdin; \
	DOCKER_CONFIG=$(CRANE_CONFIG) crane push build/image.tar "$(IMAGE):$$ver"; \
	DOCKER_CONFIG=$(CRANE_CONFIG) crane tag "$(IMAGE):$$ver" latest; \
	echo "pushed $(IMAGE):$$ver and $(IMAGE):latest"

ci: check lint ## everything a push must pass

lint: check-no-agent-files ## agent-file guard

push: ## push main to origin
	git push "$(REMOTE)" "$(BRANCH)"

# Agent files are never published. Two ways they get in: already tracked, or
# present-and-unignored when `git add -A` below sweeps the whole tree. Both are
# checked here, because a squashed history shows no file being added — a stray
# path simply appears in the root commit as though it always belonged.
check-no-agent-files: ## refuse agent files that are tracked or not ignored
	@bad=$$(git ls-files | grep -E '(^|/)(\.mcp\.json|\.claude/|\.claude-amber/)' || true); \
	if [ -n "$$bad" ]; then \
		echo "agent files are tracked and must not be published:"; \
		printf '  %s\n' $$bad; \
		echo "fix: git rm -r --cached <path>, then add it to .gitignore"; \
		exit 2; \
	fi
	@for p in .mcp.json .claude .claude-amber; do \
		if [ -e "$$p" ] && ! git check-ignore -q "$$p"; then \
			echo "$$p exists and is not gitignored — 'git add -A' would publish it"; \
			echo "fix: add $$p to .gitignore"; \
			exit 2; \
		fi; \
	done
	@echo "no agent files staged for publication"

force-push: check check-no-agent-files ## rewrite history as one signed root commit and force-push
	@test -z "$$(git status --porcelain)" || { \
		echo "Working tree is dirty. Commit, stash, or revert changes first."; \
		exit 2; \
	}
	@set -e; \
	orig_branch="$$(git branch --show-current)"; \
	test -n "$$orig_branch" || { echo "force-push: detached HEAD, check out a branch first"; exit 1; }; \
	tmp_branch="root-squash-$$(date +%s)"; \
	step="starting"; ok=0; \
	trap 'if [ "$$ok" != 1 ]; then echo "force-push FAILED while: $$step. Local history is intact on $$orig_branch; $(REMOTE)/$(BRANCH) was not replaced." >&2; git checkout -f "$$orig_branch" >/dev/null 2>&1 || true; git branch -D "$$tmp_branch" >/dev/null 2>&1 || true; exit 1; fi' EXIT; \
	step="creating the orphan branch"; git checkout --orphan "$$tmp_branch"; \
	step="staging the tree"; git add -A; \
	step="signing the root commit"; git commit -S -m "$(ROOT_COMMIT_MSG)"; \
	step="pushing to $(REMOTE)/$(BRANCH) (refused or unreachable)"; git push --force "$(REMOTE)" "$$tmp_branch:$(BRANCH)"; \
	step="verifying $(REMOTE)/$(BRANCH) equals the new commit"; \
	remote_sha="$$(git ls-remote "$(REMOTE)" "refs/heads/$(BRANCH)" | cut -f1)"; \
	test -n "$$remote_sha" && test "$$remote_sha" = "$$(git rev-parse HEAD)"; \
	ok=1; \
	git branch -M "$$tmp_branch" "$(BRANCH)"; \
	git branch --set-upstream-to="$(REMOTE)/$(BRANCH)" "$(BRANCH)" >/dev/null 2>&1 || { git fetch "$(REMOTE)" "$(BRANCH)" >/dev/null 2>&1 && git branch --set-upstream-to="$(REMOTE)/$(BRANCH)" "$(BRANCH)" >/dev/null; } || echo "warning: could not set upstream"; \
	echo "Rewrote $$orig_branch as signed root commit on $(REMOTE)/$(BRANCH)."

clean: ## remove the :build image
	docker image rm -f $(IMAGE):build 2>/dev/null || true

run: ## open a shell in :latest with this directory at /workspace
	docker run --rm -it -v "$$(pwd)":/workspace $(IMAGE):latest bash

help: ## this list
	@awk 'BEGIN {FS = ":.*## "} \
	    /^##@ / {printf "\n%s\n", substr($$0, 5)} \
	    /^[a-z][a-z0-9-]*:.*## / {printf "  %-22s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
