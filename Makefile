SHELL := /bin/bash
.PHONY: help ios update tvos

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
	install_carthage \
	install_bundler_gem \
	install_ruby_gems \
	install_carthage_dependencies

pull_request: \
	test \
	codecov_upload \
	danger

pre_setup:
	$(info iOS project setup ...)

check_for_ruby:
	$(info Checking for Ruby ...)

ifeq ($(RUBY),)	
	$(error Ruby is not installed)
endif

check_for_homebrew:
	$(info Checking for Homebrew ...)

ifeq ($(HOMEBREW),)
	$(error Homebrew is not installed)
endif

update_homebrew:
	$(info Update Homebrew ...)

	brew update

install_swift_lint:
	$(info Install swiftlint ...)

	brew unlink swiftlint || true
	brew install swiftlint
	brew link --overwrite swiftlint

install_bundler_gem:
	$(info Checking and install bundler ...)

ifeq ($(BUNDLER),)
	gem install bundler -v '~> 1.17'
else
	gem update bundler '~> 1.17'
endif

install_ruby_gems:
	$(info Install Ruby Gems ...)

	bundle install

install_carthage:
	$(info Install Carthage ...)

	brew unlink carthage || true
	brew install carthage
	brew link --overwrite carthage

install_carthage_dependencies:
	$(info Install Carthage Dependencies for iOS...)

	bundle exec fastlane carthage_bootstrap_ios

install_carthage_dependencies_tvos:
	$(info Install Carthage Dependencies for tvOS...)

	bundle exec fastlane carthage_bootstrap_tvos

update_carthage_dependencies:
	$(info Update Carthage Dependencies for iOS...)

	bundle exec fastlane carthage_update_ios

update_carthage_dependencies_tvos:
	$(info Update Carthage Dependencies for tvOS...)

	bundle exec fastlane carthage_update_tvos

pull:
	$(info Pulling new commits ...)

	git pull

## -- Source Code Tasks --

## Pull upstream and update 3rd party frameworks
update: pull submodules install_ruby_gems install_carthage_dependencies

submodules:
	$(info Updating submodules ...)

	git submodule update --init --recursive
	
## -- QA Task Runners --

codecov_upload:
	curl -s https://codecov.io/bash | bash

danger: 
	bundle exec danger

## -- Testing --

## Run test on all targets
test:
	bundle exec fastlane test

## -- Building --

developer:
	$(info Building iOS for developer profile ...)

	bundle exec fastlane build_developer
	
developer_tvos:
	$(info Building tvOS for developer profile ...)

	bundle exec fastlane build_developer :scheme ProvenanceTV-Release

## Make a .zip package of frameworks
package:
	carthage build --no-skip-current
	carthage archive PMS-UI PMSInterface

## Build for iOS
ios: | update developer

## Build for tvOS
tvos: | update install_carthage_dependencies_tvos developer_tvos

## Open the workspace
open:
	open Provenance.xcworkspace

## tag and release to github
release: | _var_VERSION
	@if ! git diff --quiet HEAD; then \
		( $(call _error,refusing to release with uncommitted changes) ; exit 1 ); \
	fi
	test
	package
	make --no-print-directory _tag VERSION=$(VERSION)
	make --no-print-directory _push VERSION=$(VERSION)

## Clear carthage caches. Helps with carthage update issues
carthage_clean:
	$(info Deleting Carthage's checkout caches...)

	rm -rf ~/Library/Caches/org.carthage.CarthageKit/dependencies/