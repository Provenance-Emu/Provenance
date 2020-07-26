#!/usr/bin/env bash

DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
. "$DIR/setup_env.sh"

PLATFORM=${1:-iOS,tvOS}
SOURCEPATH=${2:-$SRCROOT}

# Check for and optionally install build tools
prebuild() {
    echo_info "Running prebuild"
   
    if ! brew_installed; then
        echo_warn "Homebrew not installed. Will attempt to install"
        brew_install
        if ! brew_installed; then
            error_exit "Homebrew failed to install."
        fi
    else
        echo_true "Homebrew installed"
    fi

    if ! carthage_installed; then
        echo_warn "Carthage not installed. Will attempt to install"
        carthage_install
        if ! carthage_installed; then
            error_exit "Carthage failed to install."
        fi
    else
        echo_true "Carthage installed"
    fi

    if ! fastlane_installed; then
        echo_warn "Fastlane not installed. Will attempt to install"
        fastlane_install
        if ! fastlane_installed; then
            error_exit "Fastlane failed to install."
        fi
    else
        echo_true "Fastlane installed"
    fi

    return 0
}

# DESC: Main control flow
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: None
function main() {
    trap script_trap_err ERR
    trap script_trap_exit EXIT
    
    script_init "$@"
    # parse_params "$@"
    cron_init
    colour_init

     # Stop multiple scripts from installing shit at the same time
    lockfile_waithold
    prebuild

    echo_info "Boot strapping Carthage for the following setup: "
    echo_info "FASTLANE_CMD: $FASTLANE_CMD"
    echo_info "PLATFORM: $PLATFORM"
    echo_info "PATH: $SOURCEPATH"

    if fastlane_installed && bundle_installed; then
        FASTLANE_CMD="bundle exec fastlane"
    elif fastlane_installed; then
        FASTLANE_CMD="fastlane"
    fi

    if [[ "$FASTLANE_CMD" != "" ]]; then
        bundle_install_cmd
        brew_update
        echo_info "Setting up Carthage for platform $PLATFORM using \"$FASTLANE_CMD\""
        BOOTSTRAP_CMD="$FASTLANE_CMD carthage_bootstrap platform:$PLATFORM directory:\"$SOURCEPATH\""
        eval_command $BOOTSTRAP_CMD
    else
        echo "Failed to find a working fastlane command: '${FASTLANE_CMD}'"
        echo "Falling back to cartage.sh script"
        if ! carthage_installed; then
            carthage_install
        fi

        . "$DIR/carthage.sh" $PLATFORM "$SOURCEPATH"
    fi

    # Release lock
    lockfile_release
}

# Run main
main "$@"
