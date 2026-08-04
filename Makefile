SHELL := /bin/bash

# Local secrets/config: .env is gitignored; .env.sample documents every key.
# `-include` so a missing .env is fine (CI passes real env/secrets instead).
# `export` makes the values visible to recipes (release.sh, fastlane, etc.).
-include .env
export
.PHONY: help ios update tvos lite ci \
	generate-all generate-cheatdb generate-contributors generate-core-lists \
	generate-default-skins generate-licenses generate-uti generate-changelog \
	update-cheatdb update-skin-catalog update-core-versions update-core-licenses \
	test-all test-spm test-cheatdb test-scripts \
	lint audit-localization bump-build bump-minor bump-major spm-validate \
	testflight testflight-tvos testflight-all release release-dry release-tag

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

## Generate libretro cheat database if missing (for builds/tests)
ensure-cheatdb:
	@PVLookup/Scripts/generate_cheatdb_if_needed.sh

# Uses MD5 cross-referencing from DAT files for ROM hash lookup support.
# Note: libretro only ships cheats under a subset of systems in cht/; see
# Scripts/generate_cheatdb.py (SYSTEM_SHORT_NAMES / upstream comment).
## Force-regenerate libretro cheat database from libretro-database repo
update-cheatdb:
	$(info Generating libretro cheat database…)
	rm -rf /tmp/libretro-database
	rm -f PVLookup/Sources/LibretroCheatDB/Resources/libretro_cheats.sqlite.zip
	git clone --depth=1 https://github.com/libretro/libretro-database.git /tmp/libretro-database
	python3 Scripts/generate_cheatdb.py /tmp/libretro-database/cht/ \
		--dat-dir /tmp/libretro-database \
		--output PVLookup/Sources/LibretroCheatDB/Resources/libretro_cheats.sqlite
	rm -rf /tmp/libretro-database

## Scrape community Delta skin sites and generate catalog.json
update-skin-catalog:
	$(info Scraping Delta skin catalogs…)
	@if [ ! -d /tmp/scraper-venv ]; then \
		python3 -m venv /tmp/scraper-venv; \
	fi
	/tmp/scraper-venv/bin/pip install -q -r Scripts/requirements-scraper.txt
	/tmp/scraper-venv/bin/python3 Scripts/scrape_skin_catalog.py \
		--source all \
		--skip-validation \
		--output Scripts/catalog_seed.json
	cp Scripts/catalog_seed.json PVUI/Sources/PVUIBase/Resources/catalog_seed.json

## -- Code Generation --

## Run all code generators
generate-all: generate-contributors generate-core-lists generate-default-skins generate-licenses generate-uti generate-changelog update-core-versions

## Generate CONTRIBUTORS.md from git history
generate-contributors:
	$(info Generating contributors…)
	python3 Scripts/generate_contributors.py

## Generate libretro core URL lists from cores.yml manifest
generate-core-lists:
	$(info Generating core lists…)
	python3 Scripts/generate_core_lists.py generate

## Validate core lists match manifest (dry run)
validate-core-lists:
	$(info Validating core lists…)
	python3 Scripts/generate_core_lists.py validate

## Generate default DeltaSkin bundles for physical controllers
generate-default-skins:
	$(info Generating default skins…)
	python3 Scripts/generate_default_skins.py

## Generate license manifest from Core.plist + SPM dependencies
generate-licenses:
	$(info Generating license manifest…)
	python3 Scripts/generate_licenses.py

## Check licenses are up-to-date (CI validation, no writes)
check-licenses:
	$(info Checking license manifest…)
	python3 Scripts/generate_licenses.py --check

## Generate UTI/MIME type declarations for Info.plist
generate-uti:
	$(info Generating UTI declarations…)
	python3 Scripts/generate_uti_declarations.py

## Generate changelog entries from conventional commits
generate-changelog:
	$(info Generating changelog…)
	git log --oneline --no-merges $$(git describe --tags --abbrev=0 2>/dev/null || echo HEAD~50)..HEAD --format="%s" > /tmp/raw_commits.txt
	python3 Scripts/changelog_generate_entries.py
	python3 Scripts/changelog_update_file.py

## Update core version strings in Core.plist from source
update-core-versions:
	$(info Updating core versions…)
	python3 Scripts/update_core_versions.py --fix

## Validate core versions are up-to-date (CI, no writes)
check-core-versions:
	$(info Checking core versions…)
	python3 Scripts/update_core_versions.py

## Sync RetroArch Core.plist license data from libretro .info files
update-core-licenses:
	$(info Updating core licenses…)
	python3 CoresRetro/RetroArch/scripts/update_core_licenses.py

## Generate systems markdown tables from systems.plist
generate-systems-docs:
	$(info Generating systems documentation…)
	python3 Scripts/systems.py PVLibrary/Sources/PVLibrary/Resources/systems.plist

## -- Testing --

## Run all tests (SPM modules + script tests)
test-all: test-spm test-scripts

## Build and test all standalone SPM modules (Tier 0-2)
test-spm:
	$(info Running SPM module validation…)
	Scripts/spm-validate.sh

## Build and test a single SPM module (usage: make test-module MODULE=PVLogging)
test-module: | _var_MODULE
	$(info Testing $(MODULE)…)
	Scripts/spm-validate.sh $(MODULE)

## Run Python script unit tests
test-scripts:
	$(info Running script tests…)
	python3 -m pytest Scripts/test_generate_cheatdb_dat.py -v

## Run cheatdb DAT parser tests
test-cheatdb:
	$(info Running cheatdb tests…)
	python3 Scripts/test_generate_cheatdb_dat.py

## -- Linting & Auditing --

## Run SwiftLint on the project
lint:
	$(info Running SwiftLint…)
	swiftlint lint --config .swiftlint.yml

## Audit localization coverage
audit-localization:
	$(info Auditing localization…)
	Scripts/audit_localization.sh

## -- Version Management --

## Bump build number in Build.xcconfig
bump-build:
	$(info Bumping build number…)
	Scripts/bump-version.sh --build

## Bump minor version in Build.xcconfig
bump-minor:
	$(info Bumping minor version…)
	Scripts/bump-version.sh --minor

## Bump major version in Build.xcconfig
bump-major:
	$(info Bumping major version…)
	Scripts/bump-version.sh --major

## Set specific marketing version (usage: make set-version VERSION=3.5.0)
set-version: | _var_VERSION
	Scripts/bump-version.sh --set-marketing $(VERSION)

## -- Release / TestFlight --
# Wraps Scripts/release.sh. Build number auto-bumps to an epoch timestamp inside the
# script, injected into Build.xcconfig and restored on exit — no commit, no manual bump.
# TestFlight needs ASC_API_KEY_ID, ASC_API_ISSUER_ID, ASC_API_KEY_PATH in the environment.

## Archive + auto-bump build + upload iOS to TestFlight
testflight:
	Scripts/release.sh --channel testflight --platform ios

## Archive + auto-bump build + upload tvOS to TestFlight
testflight-tvos:
	Scripts/release.sh --channel testflight --platform tvos

## Archive + upload both iOS and tvOS to TestFlight
testflight-all:
	Scripts/release.sh --channel testflight --platform all

## Build + publish all channels (TestFlight + GitHub release)
release:
	Scripts/release.sh --channel all

## Print release actions without executing (dry-run)
release-dry:
	Scripts/release.sh --channel all --dry-run

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
