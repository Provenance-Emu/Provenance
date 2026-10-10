SHELL := /bin/bash

# Local secrets/config: .env is gitignored; .env.sample documents every key.
# `-include` so a missing .env is fine (CI passes real env/secrets instead).
# `export` makes the values visible to recipes (release.sh, fastlane, etc.).
-include .env
export
.PHONY: dev dev-generate dev-ui dev-azahar dev-thin dev-harness help ios update tvos lite ci maint maint-status maint-run-stale maint-hooks \
	generate-all generate-cheatdb generate-contributors generate-core-lists \
	generate-default-skins generate-licenses generate-uti generate-changelog \
	update-cheatdb update-skin-catalog update-core-versions update-core-licenses \
	test-all test-spm test-cheatdb test-scripts \
	lint audit-localization bump-build bump-minor bump-major spm-validate \
	testflight testflight-tvos testflight-all release release-dry release-tag \
	_release-preflight

# --- 1Password secret resolution -------------------------------------------
# .env may hold `op://` REFERENCES rather than values (see
# Scripts/release/setup-release-secrets.py). `-include .env` above would then export the
# literal string "op://..." into release.sh, which fails in a confusing way.
# When references are present, run release.sh under `op run`, which resolves them
# into the child process environment only — never to disk, and masked in output.
ENV_HAS_OP_REFS := $(shell test -f .env && grep -qE '^[A-Za-z_][A-Za-z0-9_]*=op://' .env && echo 1)
ifeq ($(ENV_HAS_OP_REFS),1)
RELEASE_RUNNER := op run --env-file=.env --
else
RELEASE_RUNNER :=
endif

RUBY := $(shell command -v ruby 2>/dev/null)
HOMEBREW := $(shell command -v brew 2>/dev/null)
BUNDLER := $(shell command -v bundle 2>/dev/null)

default: help

# Add the following 'help' target to your Makefile
# And add help text after each target name starting with '\#\#'
# A category can be added with @category

# COLORS
GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
WHITE  := $(shell tput -Txterm setaf 7)
RESET  := $(shell tput -Txterm sgr0)

## ----- Helper functions ------

# Pattern-rule prerequisite below: make 3.81 (macOS) skips a pattern rule whose prerequisite has no rule.
FORCE:
.PHONY: FORCE

# Helper target for declaring an external executable as a recipe dependency.
# For example,
#   `my_target: | _program_awk`
# will fail before running the target named `my_target` if the command `awk` is
# not found on the system path.
_program_%: FORCE
	@_=$(or $(shell which $* 2> /dev/null),$(error `$*` command not found. Please install `$*` and try again))

# Helper target for declaring required environment variables.
#
# For example,
#   `my_target`: | _var_PARAMETER`
#
# will fail before running `my_target` if the variable `PARAMETER` is not declared.
_var_%: FORCE
	@_=$(or $($*),$(error `$*` is a required parameter))

_tag: | _var_VERSION
	make --no-print-directory -B README.md
	git commit -am "Tagging release $(VERSION)"
	git tag -a $(VERSION) $(if $(NOTES),-m '$(NOTES)',-m $(VERSION))
# Fails fast with actionable guidance when .env uses op:// references but the
# 1Password CLI is unavailable or locked — otherwise release.sh would run with
# unresolved reference strings and fail late, after a full archive build.
.PHONY: _release-preflight
_release-preflight:
ifeq ($(ENV_HAS_OP_REFS),1)
	@command -v op >/dev/null 2>&1 || { \
		echo "error: .env uses op:// references but the 1Password CLI is not installed."; \
		echo "       brew install 1password-cli"; exit 1; }
	@# Deliberately NOT gating on `op whoami`: it exits non-zero in make's
	@# non-interactive subshell even when signed in, because it cannot surface the
	@# biometric prompt without a TTY. `op run` handles unlocking itself and
	@# reports its own auth errors clearly, so let it be the authority.
	@echo "==> Resolving secrets from 1Password (op run)"
	@# Authenticate against App Store Connect BEFORE the archive. xcodebuild only
	@# authenticates at UPLOAD, so a bad issuer ID or revoked key otherwise costs a
	@# full 30+ minute build before failing with "No Accounts with App Store Connect
	@# Access". This round-trips in seconds via notarytool.
	@$(RELEASE_RUNNER) python3 Scripts/release/setup-release-secrets.py --preflight
endif

.PHONY: _tag

_push: | _var_VERSION
	git push origin $(VERSION)
	git push origin master
.PHONY: _push

## ------ Commmands -----------

TARGET_MAX_CHAR_NUM=20
## Show help
help:
	@echo ''
	@echo 'Usage:'
	@echo '  ${YELLOW}make${RESET} ${GREEN}<target>${RESET}'
	@echo ''
	@echo 'Targets:'
	@awk '/^[a-zA-Z\-\_0-9]+:/ { \
		helpMessage = match(lastLine, /^## (.*)/); \
		if (helpMessage) { \
			helpCommand = substr($$1, 0, index($$1, ":")-1); \
			helpMessage = substr(lastLine, RSTART + 3, RLENGTH); \
			printf "  ${YELLOW}%-$(TARGET_MAX_CHAR_NUM)s${RESET} ${GREEN}%s${RESET}\n", helpCommand, helpMessage; \
		} \
	} \
	{ lastLine = $$0 }' \
	$(MAKEFILE_LIST)

## Install dependencies.
setup: \
	pre_setup \
	check_for_ruby \
	check_for_homebrew \
	update_homebrew \
	install_bundler_gem \
	install_ruby_gems

pull_request: \
	test \
	codecov_upload \
	danger

pre_setup:
	$(info Project setup…)

check_for_ruby:
	$(info Checking for Ruby…)

ifeq ($(RUBY),)
	$(error Ruby is not installed.)
endif

check_for_homebrew:
	$(info Checking for Homebrew…)

ifeq ($(HOMEBREW),)
	$(error Homebrew is not installed)
endif

update_homebrew:
	$(info Updating Homebrew…)

	brew update

install_swift_lint:
	$(info Install swiftlint…)

	brew unlink swiftlint || true
	brew install swiftlint
	brew link --overwrite swiftlint

install_bundler_gem:
	$(info Checking and installing bundler…)

ifeq ($(BUNDLER),)
	gem install bundler -v '~> 1.17'
else
	gem update bundler '~> 1.17'
endif

install_ruby_gems:
	$(info Installing Ruby gems…)

	bundle install

pull:
	$(info Pulling new commits…)

	git stash push || true
	git pull
	git stash pop || true

## -- Source Code Tasks --

## Pull upstream and update 3rd party frameworks
update: pull submodules install_ruby_gems

submodules:
	$(info Updating submodules…)

	git submodule update --init --recursive

## -- QA Task Runners --

codecov_upload:
	curl -s https://codecov.io/bash | bash

danger:
	bundle exec danger

## -- Fastlane Testing --

## Run test on all targets (via fastlane)
test:
	bundle exec fastlane test

## -- Building --

## Fast CI simulator build (no cores, no code signing)
lite:
	$(info Building Provenance-CI for iOS Simulator…)

	xcodebuild build \
		-workspace Provenance.xcworkspace \
		-scheme "Provenance-CI" \
		-destination "generic/platform=iOS Simulator" \
		-skipPackagePluginValidation \
		-skipMacroValidation \
		CODE_SIGNING_ALLOWED=NO \
		| xcbeautify || xcodebuild build \
		-workspace Provenance.xcworkspace \
		-scheme "Provenance-CI" \
		-destination "generic/platform=iOS Simulator" \
		-skipPackagePluginValidation \
		-skipMacroValidation \
		CODE_SIGNING_ALLOWED=NO

## Alias for lite (CI build)
ci: lite

developer_ios:
	$(info Building iOS for Developer profile…)

	bundle exec fastlane build_developer scheme:Provenance-Release

developer_tvos:
	$(info Building tvOS for Developer profile…)

	bundle exec fastlane build_developer scheme:ProvenanceTV-Release

## Update & build for iOS
ios: | update developer_ios

## Update & build for tvOS
tvos: | update developer_tvos

## Open the workspace
open:
	open Provenance.xcworkspace

## Dev workspace (Tuist; see docs/superpowers/specs/2026-10-10-dev-workspace-design.md)
TUIST ?= mise exec -- tuist
DEV_WORKSPACE := Provenance-Dev.xcworkspace
DEV_DERIVED ?= $(CURDIR)/build/dev-dd
DEV_DESTINATION ?= generic/platform=iOS Simulator

# Cores linked as .prebuilt xcframeworks must exist before `tuist generate` (Tuist reads them
# eagerly). None of the initial focused apps use one; add e.g. "dolphin" when one does.
DEV_PREBUILT_CORES ?=
DEV_SLICE ?= ios-sim
dev-generate:
	@for core in $(DEV_PREBUILT_CORES); do python3 Scripts/cores/build_slice.py $$core $(DEV_SLICE) || exit 1; done
	$(TUIST) generate --no-open

dev: dev-generate
	open $(DEV_WORKSPACE)

# Build one focused app: make _dev-build DEV_SCHEME=Provenance-Dev-UI
_dev-build: dev-generate
	xcodebuild build \
		-workspace $(DEV_WORKSPACE) \
		-scheme "$(DEV_SCHEME)" \
		-destination "$(DEV_DESTINATION)" \
		-derivedDataPath "$(DEV_DERIVED)" \
		-skipPackagePluginValidation \
		-skipMacroValidation

dev-ui:
	$(MAKE) _dev-build DEV_SCHEME=Provenance-Dev-UI

dev-azahar:
	$(MAKE) _dev-build DEV_SCHEME=Provenance-Dev-Azahar

dev-thin:
	$(MAKE) _dev-build DEV_SCHEME=Provenance-Dev-Thin

## Run the dev harness on the booted simulator:
##   make dev-harness ROM=path/to/rom [TARGET=ui|azahar] [FRAMES=300] [CORE=com.provenance.core.stella]
## Provenance-Dev-Thin is device-only (libretro dylibs don't load in the simulator).
## Thin on a device: run Provenance-Dev-Thin from Xcode with scheme arguments
##   -PVHarnessROM Documents/<rom> -PVHarnessFrames 300
## after copying the ROM into the app's Documents (Files app or Xcode's Devices window), then
## download the container and read Documents/Harness/<timestamp>/.
TARGET ?= ui
FRAMES ?= 300
CORE ?=
dev-harness: | _var_ROM
	DEV_DERIVED="$(DEV_DERIVED)" Scripts/dev/run_harness.sh "$(ROM)" "$(TARGET)" "$(FRAMES)" "$(CORE)"

## Generate libretro cheat database if missing (for builds/tests)
ensure-cheatdb:
	@PVLookup/Scripts/generate_cheatdb_if_needed.sh

# Uses MD5 cross-referencing from DAT files for ROM hash lookup support.
# Note: libretro only ships cheats under a subset of systems in cht/; see
# Scripts/generators/generate_cheatdb.py (SYSTEM_SHORT_NAMES / upstream comment).
## Force-regenerate libretro cheat database from libretro-database repo
update-cheatdb:
	$(info Generating libretro cheat database…)
	rm -rf /tmp/libretro-database
	rm -f PVLookup/Sources/LibretroCheatDB/Resources/libretro_cheats.sqlite.zip
	git clone --depth=1 https://github.com/libretro/libretro-database.git /tmp/libretro-database
	python3 Scripts/generators/generate_cheatdb.py /tmp/libretro-database/cht/ \
		--dat-dir /tmp/libretro-database \
		--output PVLookup/Sources/LibretroCheatDB/Resources/libretro_cheats.sqlite
	rm -rf /tmp/libretro-database

## Scrape community Delta skin sites and generate catalog.json
update-skin-catalog:
	$(info Scraping Delta skin catalogs…)
	@if [ ! -d /tmp/scraper-venv ]; then \
		python3 -m venv /tmp/scraper-venv; \
	fi
	/tmp/scraper-venv/bin/pip install -q -r Scripts/generators/requirements-scraper.txt
	/tmp/scraper-venv/bin/python3 Scripts/generators/scrape_skin_catalog.py \
		--source all \
		--skip-validation \
		--output Scripts/generators/catalog_seed.json
	cp Scripts/generators/catalog_seed.json PVUI/Sources/PVUIBase/Resources/catalog_seed.json

## -- Maintenance --

## Maintenance dashboard: stale jobs, run buttons, unregistered scripts
maint:
	python3 Scripts/maint/maint.py serve

## Show stale maintenance jobs (add ARGS=--all for on-demand ones)
maint-status:
	python3 Scripts/maint/maint.py status $(ARGS)

## Run every stale job that is safe to automate
maint-run-stale:
	python3 Scripts/maint/maint.py run --stale --auto-only

## Install the report-only git hook (post-merge / post-checkout)
maint-hooks:
	python3 Scripts/maint/maint.py hooks install

## -- Code Generation --

## Run all code generators
generate-all: generate-contributors generate-core-lists generate-default-skins generate-licenses generate-uti generate-changelog update-core-versions

## Generate CONTRIBUTORS.md from git history
generate-contributors:
	$(info Generating contributors…)
	python3 Scripts/generators/generate_contributors.py

## Generate libretro core URL lists from cores.yml manifest
generate-core-lists:
	$(info Generating core lists…)
	python3 Scripts/generators/generate_core_lists.py generate

## Validate core lists match manifest (dry run)
validate-core-lists:
	$(info Validating core lists…)
	python3 Scripts/generators/generate_core_lists.py validate

## Generate default DeltaSkin bundles for physical controllers
generate-default-skins:
	$(info Generating default skins…)
	python3 Scripts/generators/generate_default_skins.py

## Generate license manifest from Core.plist + SPM dependencies
generate-licenses:
	$(info Generating license manifest…)
	python3 Scripts/generators/generate_licenses.py

## Check licenses are up-to-date (CI validation, no writes)
check-licenses:
	$(info Checking license manifest…)
	python3 Scripts/generators/generate_licenses.py --check

## Generate UTI/MIME type declarations for Info.plist
generate-uti:
	$(info Generating UTI declarations…)
	python3 Scripts/generators/generate_uti_declarations.py

## Generate changelog entries from conventional commits
generate-changelog:
	$(info Generating changelog…)
	git log --oneline --no-merges $$(git describe --tags --abbrev=0 2>/dev/null || echo HEAD~50)..HEAD --format="%s" > /tmp/raw_commits.txt
	python3 Scripts/generators/changelog_generate_entries.py
	python3 Scripts/generators/changelog_update_file.py

## Update core version strings in Core.plist from source
update-core-versions:
	$(info Updating core versions…)
	python3 Scripts/generators/update_core_versions.py --fix

## Validate core versions are up-to-date (CI, no writes)
check-core-versions:
	$(info Checking core versions…)
	python3 Scripts/generators/update_core_versions.py

## Sync RetroArch Core.plist license data from libretro .info files
update-core-licenses:
	$(info Updating core licenses…)
	python3 CoresRetro/RetroArch/scripts/update_core_licenses.py

## Generate systems markdown tables from systems.plist
generate-systems-docs:
	$(info Generating systems documentation…)
	python3 Scripts/generators/systems.py PVLibrary/Sources/PVLibrary/Resources/systems.plist

## -- Testing --

## Run all tests (SPM modules + script tests)
test-all: test-spm test-scripts

## Build and test all standalone SPM modules (Tier 0-2)
test-spm:
	$(info Running SPM module validation…)
	Scripts/audits/spm-validate.sh

## Build and test a single SPM module (usage: make test-module MODULE=PVLogging)
test-module: | _var_MODULE
	$(info Testing $(MODULE)…)
	Scripts/audits/spm-validate.sh $(MODULE)

## Run Python script unit tests
test-scripts:
	$(info Running script tests…)
	python3 -m pytest Scripts/tests/test_generate_cheatdb_dat.py -v

## Run cheatdb DAT parser tests
test-cheatdb:
	$(info Running cheatdb tests…)
	python3 Scripts/tests/test_generate_cheatdb_dat.py

## -- Linting & Auditing --

## Run SwiftLint on the project
lint:
	$(info Running SwiftLint…)
	swiftlint lint --config .swiftlint.yml

## Audit localization coverage
audit-localization:
	$(info Auditing localization…)
	Scripts/audits/audit_localization.sh

## -- Version Management --

## Bump build number in Build.xcconfig
bump-build:
	$(info Bumping build number…)
	Scripts/release/bump-version.sh --build

## Bump minor version in Build.xcconfig
bump-minor:
	$(info Bumping minor version…)
	Scripts/release/bump-version.sh --minor

## Bump major version in Build.xcconfig
bump-major:
	$(info Bumping major version…)
	Scripts/release/bump-version.sh --major

## Set specific marketing version (usage: make set-version VERSION=3.5.0)
set-version: | _var_VERSION
	Scripts/release/bump-version.sh --set-marketing $(VERSION)

## -- Release / TestFlight --
# Wraps Scripts/release/release.sh. Build number auto-bumps to an epoch timestamp inside the
# script, injected into Build.xcconfig and restored on exit — no commit, no manual bump.
# TestFlight needs ASC_API_KEY_ID, ASC_API_ISSUER_ID, ASC_API_KEY_PATH in the environment.

## Archive + auto-bump build + upload iOS to TestFlight
testflight: _release-preflight
	$(RELEASE_RUNNER) Scripts/release/release.sh --channel testflight --platform ios

## Archive + auto-bump build + upload tvOS to TestFlight
testflight-tvos: _release-preflight
	$(RELEASE_RUNNER) Scripts/release/release.sh --channel testflight --platform tvos

## Archive + upload both iOS and tvOS to TestFlight
testflight-all: _release-preflight
	$(RELEASE_RUNNER) Scripts/release/release.sh --channel testflight --platform all

## Build + publish all channels (TestFlight + GitHub release)
release:
	$(RELEASE_RUNNER) Scripts/release/release.sh --channel all

## Print release actions without executing (dry-run)
release-dry:
	$(RELEASE_RUNNER) Scripts/release/release.sh --channel all --dry-run

## -- Aliases --

## Alias: validate standalone SPM modules
spm-validate: test-spm

## tag and release to github (legacy fastlane/tag flow; see `release` for TestFlight)
release-tag: | _var_VERSION
	@if ! git diff --quiet HEAD; then \
		( $(call _error,refusing to release with uncommitted changes) ; exit 1 ); \
	fi
	test
	package
	make --no-print-directory _tag VERSION=$(VERSION)
	make --no-print-directory _push VERSION=$(VERSION)
