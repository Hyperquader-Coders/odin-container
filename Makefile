IMAGE ?= hyperquader/odin-container
ODIN_VERSION ?=
BRANCH ?= main
REMOTE ?= origin
ROOT_COMMIT_MSG ?= Initial odin-container

.PHONY: build check tag deploy ci push force-push clean run check-no-agent-files

# Builds :build from the Dockerfile. ODIN_VERSION pins the amber-odin
# package version; empty tracks the newest in the archive. VCS_REF/BUILD_DATE
# feed the image's org.opencontainers.image.* labels.
VCS_REF := $(shell git rev-parse --short HEAD 2>/dev/null || echo unknown)
BUILD_DATE := $(shell date -u +%Y-%m-%dT%H:%M:%SZ)

build:
	docker build $(if $(ODIN_VERSION),--build-arg ODIN_VERSION=$(ODIN_VERSION)) \
		--build-arg VCS_REF=$(VCS_REF) \
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		-t $(IMAGE):build .

# Speaks to the real packaged binaries rather than trusting the build log.
check: build
	docker run --rm $(IMAGE):build sh -c 'odin version && command -v ols >/dev/null && echo "check: OK"'

# Tags :build as the odin version it actually carries plus :latest, so a
# pulled image says what it contains instead of just "the newest push".
# `odin version` prints e.g. "odin version dev-2026-08-nightly:902106f" —
# the last field, with ':' swapped for '-' since Docker tags forbid it.
tag: check
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
deploy: tag
	@test -n "$(DOCKER_TOKEN)" || { echo "DOCKER_TOKEN not set"; exit 1; }
	@test -n "$(DOCKER_USER)" || { echo "DOCKER_USER not set"; exit 1; }
	@ver="$$(cat build/version)"; \
	rm -rf $(CRANE_CONFIG); mkdir -p $(CRANE_CONFIG); \
	trap 'rm -rf $(CRANE_CONFIG) build/image.tar' EXIT; \
	docker save $(IMAGE):build -o build/image.tar; \
	echo "$(DOCKER_TOKEN)" | DOCKER_CONFIG=$(CRANE_CONFIG) crane auth login index.docker.io -u "$(DOCKER_USER)" --password-stdin; \
	DOCKER_CONFIG=$(CRANE_CONFIG) crane push build/image.tar "$(IMAGE):$$ver"; \
	DOCKER_CONFIG=$(CRANE_CONFIG) crane tag "$(IMAGE):$$ver" latest; \
	echo "pushed $(IMAGE):$$ver and $(IMAGE):latest"

ci: check

push:
	git push "$(REMOTE)" "$(BRANCH)"

# Agent files are never published. Two ways they get in: already tracked, or
# present-and-unignored when `git add -A` below sweeps the whole tree. Both are
# checked here, because a squashed history shows no file being added — a stray
# path simply appears in the root commit as though it always belonged.
check-no-agent-files:
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

force-push: check check-no-agent-files
	@test -z "$$(git status --porcelain)" || { \
		echo "Working tree is dirty. Commit, stash, or revert changes first."; \
		exit 2; \
	}
	@orig_branch="$$(git branch --show-current)"; \
	tmp_branch="root-squash-$$(date +%s)"; \
	git checkout --orphan "$$tmp_branch"; \
	git add -A; \
	git commit -S -m "$(ROOT_COMMIT_MSG)"; \
	git branch -D "$(BRANCH)" 2>/dev/null || true; \
	git branch -m "$(BRANCH)"; \
	git push --force --set-upstream "$(REMOTE)" "$(BRANCH)"; \
	echo "Rewrote $$orig_branch as signed root commit on $(REMOTE)/$(BRANCH)."

clean:
	docker image rm -f $(IMAGE):build 2>/dev/null || true

run:
	docker run --rm -it -v "$$(pwd)":/workspace $(IMAGE):latest bash
