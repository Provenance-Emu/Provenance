if [ -f ~/.bashrc ]; then
    source ~/.bashrc 2> /dev/null
fi

if [ -f ~/.bash_profile ]; then
    source ~/.bash_profile 2> /dev/null
fi

export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export FASTLANE_SKIP_UPDATE_CHECK=true

if [[ "$PATH" != *".fastlane/bin"* ]]; then
  echo "Adding hypothetical fastlane bin folder to PATH since many user forget to update PATH after install"
  export PATH="$HOME/.fastlane/bin:$PATH"
fi

error_exit()
{
    local MSG="${1:-"Unknown Error"}"
    echo "error: $MSG" 1>&2
    if ! is_interactive_shell; then
      local title=${2:-$(basename $0)}

      osascript <<EOT
      tell app "System Events"
        display dialog "Error: ${MSG}" buttons {"OK"} default button 1 with icon stop with title "$title"
        return  -- Suppress result
      end tell
EOT
    fi
    exit 1
}

echo_info()
{
  local MSG="${1:-""}"
  echo "💚 $MSG" 1>&2
  return 0
}

echo_true()
{
  local MSG="${1:-""}"
  echo "✅ $MSG" 1>&2
  return 0
}

echo_warn() {
  local MSG="${1:-""}"
  echo "⚠️ $MSG" 1>&2
  return 0
}

echo_waiting()
{
  local MSG="${1:-""}"
  echo "🔄 $MSG" 1>&2
  return 0
}

success_exit()
{
  echo "${1:-"Completed"}" 1>&2
  exit 0
}

success_exit()
{
    echo "${1:-"Completed"}" 1>&2
    exit 0
}

eval_command() {
  echo "● : $@"
  "$@";
}

# Ensure not root
{
  if [ $(id -u) = 0 ]; then 
    error_exit "Please do not run this script as root"
  fi
}

get_swift_version() {
    "$1" --version 2>/dev/null | sed -ne 's/^Apple Swift version \([^\b ]*\).*/\1/p'
}

get_xcode_version() {
    "$1" -version 2>/dev/null | sed -ne 's/^Xcode \([^\b ]*\).*/\1/p'
}

brew_installed() {
  [ -x "$(command -v brew)" ]
  return
}

{
  cleanup() {
    if [ -f /tmp/askpass.sh ]; then
      rm -f /tmp/askpass.sh
    fi

    if [ -f "$LOCK_FILE" ]; then
      rm -f "$LOCK_FILE"
    fi
  }

  trap cleanup EXIT
}

read_password() {
  if [ "$SUDO_ASKPASS" = "/tmp/askpass.sh" ]; then
    echo "Password was already prompted for. Skipping"
    return 0
  fi

  if ! is_interactive_shell; then
    while :; do # Loop until valid input is entered or Cancel is pressed.  
      PASSWORD=$(osascript -e 'Tell application "System Events" to display dialog "Enter your login password:" default answer "" with hidden answer' -e 'text returned of result' 2>/dev/null)  
      if (( $? )); then exit 1; fi  # Abort, if user pressed Cancel.  
      PASSWORD=$(echo -n "$PASSWORD" | sed 's/^ *//' | sed 's/ *$//')  # Trim leading and trailing whitespace.  
      if [[ -z "$PASSWORD" ]]; then  
          # The user left the project name blank.
          echo "Invalid password entered"
          osascript -e 'Tell application "System Events" to display alert "You must enter a password; please try again." as warning' >/dev/null  
          # Continue loop to prompt again.  
      else  
          # Valid input: exit loop and continue.  
          echo "Valid password entered"
          break  
      fi  
    done  
  else
    echo "This script requires admin priviledges, but cannot be run as root."
    echo -n Password:
    read -s PASSWORD
    echo
  fi

  echo "#!/bin/bash" > /tmp/askpass.sh
  echo "echo '$PASSWORD'" >> /tmp/askpass.sh
  echo "$PASSWORD" | sudo -S chmod 777 /tmp/askpass.sh
  export SUDO_ASKPASS="/tmp/askpass.sh"
  echo "Created temp password store /tmp/askpass.sh"
}

install_xcode_cli_tools() {
  xcode-select --install
  sleep 1
  osascript -e <<EOD
    tell application "System Events"
      tell process "Install Command Line Developer Tools"
        keystroke return
        click button "Agree" of window "License Agreement"
        delay 1
        keystroke return
        repeat
          delay 5
          if exists (button "Done" of window 1) then
            click button "Done" of window 1
            exit repeat
          end if
        end repeat
      end tell
    end tell
EOD
}

is_interactive_shell() {
  [[ $- == *i* ]]
  return
}

ui_prompt() {
  local MESSAGE=${1:-"Would you like to continue?"}
  local TITLE=${2:-"Provenance"}
  local OKBUTTON_TITLE=${3:-"OK"}
  local ICON="note"

  if [[ "$MESSAGE" == *"rror"* ]]; then
    ICON="stop"
  elif [[ "$MESSAGE" == *"arning"* ]]; then
    ICON="caution"
  fi
  
  osascript <<END
  tell application id "com.apple.systemevents"
    set myMsg to "${MESSAGE}"
    set theResp to display dialog myMsg buttons {"Cancel", "${OKBUTTON_TITLE}"} default button 2 with icon ${ICON} with title "${TITLE}"
  end tell

  # Following is not really necessary. Cancel returns 1 and OK 0 ...
  if button returned of theResp is "Cancel" then
    return 1
  end if
END

    # Check status of osascript
    if [ "$?" != "0" ]; then
      false
    else
      true
    fi
}

brew_install() {
  if brew_installed; then
    echo "Homebrew already installed"
    return 0
  fi

  echo "Attempting to install brew (Homebrew)"

  if is_interactive_shell; then
    /usr/bin/env ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  else
    echo "Script not in interactive shell. Prompting for user input via Apple Script."
    
    read -r -d '' local MSG << EOM
Warning Homebrew is not installed!

Homebrew is a command line based software package manager and as is required to install and run 'Fastlane'.

These tools are required to build Provenance from source.

Would you like to install Homebrew now?
EOM

    ui_prompt "$MSG" "Missing Homebrew" "Install"

    if [ "$?" = "0" ]; then
      echo "Prompting for password"
      read_password
      echo "Attempting install of Homebrew"
      CI=true /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
      return
    else
      error_exit "Could not continue build without Homebrew"
    fi
  fi
}

brew_update() {
  if brew_installed; then
    brew update
    brew outdated swiftlint || brew upgrade swiftlint
  else
    echo "Homebrew not installed. Skipping update."
  fi
}

bundle_installed() {
   [ -x "$(command -v bundle)" ]
   return
}

bundle_install_cmd() {
  if bundle_installed; then
    echo "ruby bundle installed. Running 'bundle install'"
    bundle install
  fi
}

fastlane_installed() {
  [ -x "$(command -v fastlane)" ]
  return
}

fastlane_install() {
  if fastlane_installed; then
    echo "Fastlane is installed. Skipping install."
    return 0
  fi

  # Using RubyGems
  # sudo gem install fastlane -NV

  # Alternatively using Homebrew
  # brew cask install fastlane
  echo "fastlane is not installed. Will attempt to install."
  
  local NEED_ROOT_MESSAGE=""
  if ! brew_installed; then
    NEED_ROOT_MESSAGE="No Homebrew install detected! 'fastlane' will be installed as a ruby gem. This will prompt for your login password to install."
  fi
  
  read -r -d '' local MSG << EOM
  Warning Fastlane is not installed. 
  
  Fastlane is an open source tool required to build and sign Provenance. 
  ${NEED_ROOT_MESSAGE}
  Would you like to install it?
EOM
  ui_prompt "$MSG" "Missing Fastlane" "Install"
  
  if [ "$?" != "0" ]; then
    echo "User denied us to install fastlane"
    error_exit "Could not continue build without Fastlane. Please install manually (https://docs.fastlane.tools/getting-started/ios/setup/)" "Fastlane Required"
  else
    echo "User accepted us to install fastlane"
  fi

  if brew_installed; then
    echo "Installing via homebrew. No admin access required."
    brew cask install fastlane
  else
    echo "No Homebrew. Attempting to install fastlane via ruby"

    if ruby_requires_root; then
      echo "Ruby requires admin access"
      echo "Prompting for password"
      read_password
      echo "Installing fastlane gem"
      sudo gem install fastlane -NV
    else
      gem install fastlane -NV
    fi
  fi

  ui_prompt "It is recomended to configure your PATH and LOCAL shell enviroment variables according to 'fastlane's documentation to ensure proper behaviour. See https://docs.fastlane.tools/getting-started/ios/setup/#set-up-environment-variables" "Fastlane: Action Required" "Take me there..."
  if [ "$?" != "0" ]; then
     osascript -e 'open location "https://docs.fastlane.tools/getting-started/ios/setup/#set-up-environment-variables"'
  fi

  return 0
}

ruby_requires_root() {
  if [ $RUBY_PATH == "/usr/bin/ruby" ]; then
    return true
  else
    return false
  fi
}

github_connection_test() {
  nc -zw1 github.com 443 > /dev/null
  return
}

lockfile_waithold()
{
  local LOCK_NAME=${1:-"xcode"}
  local LOCK_FILE="/tmp/$LOCK_NAME.lock"

  declare -ir time_beg=$(date '+%s')
  # declare -ir maxtime=7140  # 7140 s = 1 hour 59 min.
  declare -ir maxtime=600  # 600 s = 10 min.

  echo "🔑 : Waiting up to ${maxtime}s for $LOCK_FILE ..."
  while ! \
      (set -o noclobber ; \
      echo -e "DATE:$(date)\nUSER:$(whoami)\nPID:$$" > "$LOCK_FILE" \ 
      ) 2>/dev/null
  do
      if [ $(( $(date '+%s') - ${time_beg})) -gt ${maxtime} ] ; then
          echo "🔑 : ! waited too long for $LOCK_FILE" 1>&2
          return 1
      fi
      sleep 1
  done
  echo "🔑 : no longer waint for lock $LOCK_FILE"

  trap "lockfile_release $LOCK_NAME" EXIT

  return 0
 }

lockfile_release()
 {
  local LOCK_NAME=${1:-"provenance"}
  local LOCK_FILE="/tmp/$LOCK_NAME.lock"

  echo "🔑 : Releasing lock $LOCK_FILE"
  if [ -f $LOCK_FILE ]; then
    rm -f "$LOCK_FILE"
  fi
 }
 
 # DESC: Handler for unexpected errors
# ARGS: $1 (optional): Exit code (defaults to 1)
# OUTS: None
script_trap_err() {
    local exit_code=1

    # Disable the error trap handler to prevent potential recursion
    trap - ERR

    # Consider any further errors non-fatal to ensure we run to completion
    set +o errexit
    set +o pipefail

    # Validate any provided exit code
    if [[ ${1-} =~ ^[0-9]+$ ]]; then
        exit_code="$1"
    fi

    # Output debug data if in Cron mode
    if [[ -n ${cron-} ]]; then
        # Restore original file output descriptors
        if [[ -n ${script_output-} ]]; then
            exec 1>&3 2>&4
        fi

        # Print basic debugging information
        printf '%b\n' "$ta_none"
        printf '***** Abnormal termination of script *****\n'
        printf 'Script Path:            %s\n' "$script_path"
        printf 'Script Parameters:      %s\n' "$script_params"
        printf 'Script Exit Code:       %s\n' "$exit_code"

        # Print the script log if we have it. It's possible we may not if we
        # failed before we even called cron_init(). This can happen if bad
        # parameters were passed to the script so we bailed out very early.
        if [[ -n ${script_output-} ]]; then
            printf 'Script Output:\n\n%s' "$(cat "$script_output")"
        else
            printf 'Script Output:          None (failed before log init)\n'
        fi
    fi

    # Exit with failure status
    exit "$exit_code"
}


# DESC: Handler for exiting the script
# ARGS: None
# OUTS: None
script_trap_exit() {
    cd "$orig_cwd"

    # Remove Cron mode script log
    if [[ -n ${cron-} && -f ${script_output-} ]]; then
        rm "$script_output"
    fi

    # Remove script execution lock
    if [[ -d ${script_lock-} ]]; then
        rmdir "$script_lock"
    fi

    # Restore terminal colours
    printf '%b' "$ta_none"
}


# DESC: Exit script with the given message
# ARGS: $1 (required): Message to print on exit
#       $2 (optional): Exit code (defaults to 0)
# OUTS: None
script_exit() {
    if [[ $# -eq 1 ]]; then
        printf '%s\n' "$1"
        exit 0
    fi

    if [[ ${2-} =~ ^[0-9]+$ ]]; then
        printf '%b\n' "$1"
        # If we've been provided a non-zero exit code run the error trap
        if [[ $2 -ne 0 ]]; then
            script_trap_err "$2"
        else
            exit 0
        fi
    fi

    script_exit 'Missing required argument to script_exit()!' 2
}

# DESC: Generic script initialisation
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: $orig_cwd: The current working directory when the script was run
#       $script_path: The full path to the script
#       $script_dir: The directory path of the script
#       $script_name: The file name of the script
#       $script_params: The original parameters provided to the script
#       $ta_none: The ANSI control code to reset all text attributes
# NOTE: $script_path only contains the path that was used to call the script
#       and will not resolve any symlinks which may be present in the path.
#       You can use a tool like realpath to obtain the "true" path. The same
#       caveat applies to both the $script_dir and $script_name variables.
script_init() {
    # Useful paths
    readonly orig_cwd="$PWD"
    readonly script_path="${BASH_SOURCE[0]}"
    readonly script_dir="$(dirname "$script_path")"
    readonly script_name="$(basename "$script_path")"
    readonly script_params="$*"

    # Important to always set as we use it in the exit handler
    readonly ta_none="$(tput sgr0 2> /dev/null || true)"
}

# DESC: Initialise colour variables
# ARGS: None
# OUTS: Read-only variables with ANSI control codes
# NOTE: If --no-colour was set the variables will be empty
colour_init() {
    if [[ -z ${no_colour-} ]]; then
        # Text attributes
        readonly ta_bold="$(tput bold 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly ta_uscore="$(tput smul 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly ta_blink="$(tput blink 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly ta_reverse="$(tput rev 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly ta_conceal="$(tput invis 2> /dev/null || true)"
        printf '%b' "$ta_none"

        # Foreground codes
        readonly fg_black="$(tput setaf 0 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_blue="$(tput setaf 4 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_cyan="$(tput setaf 6 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_green="$(tput setaf 2 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_magenta="$(tput setaf 5 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_red="$(tput setaf 1 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_white="$(tput setaf 7 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_yellow="$(tput setaf 3 2> /dev/null || true)"
        printf '%b' "$ta_none"

        # Background codes
        readonly bg_black="$(tput setab 0 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_blue="$(tput setab 4 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_cyan="$(tput setab 6 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_green="$(tput setab 2 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_magenta="$(tput setab 5 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_red="$(tput setab 1 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_white="$(tput setab 7 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_yellow="$(tput setab 3 2> /dev/null || true)"
        printf '%b' "$ta_none"
    else
        # Text attributes
        readonly ta_bold=''
        readonly ta_uscore=''
        readonly ta_blink=''
        readonly ta_reverse=''
        readonly ta_conceal=''

        # Foreground codes
        readonly fg_black=''
        readonly fg_blue=''
        readonly fg_cyan=''
        readonly fg_green=''
        readonly fg_magenta=''
        readonly fg_red=''
        readonly fg_white=''
        readonly fg_yellow=''

        # Background codes
        readonly bg_black=''
        readonly bg_blue=''
        readonly bg_cyan=''
        readonly bg_green=''
        readonly bg_magenta=''
        readonly bg_red=''
        readonly bg_white=''
        readonly bg_yellow=''
    fi
}


# DESC: Initialise Cron mode
# ARGS: None
# OUTS: $script_output: Path to the file stdout & stderr was redirected to
cron_init() {
    if [[ -n ${cron-} ]]; then
        # Redirect all output to a temporary file
        readonly script_output="$(mktemp --tmpdir "$script_name".XXXXX)"
        exec 3>&1 4>&2 1>"$script_output" 2>&1
    fi
}


# DESC: Acquire script lock
# ARGS: $1 (optional): Scope of script execution lock (system or user)
# OUTS: $script_lock: Path to the directory indicating we have the script lock
# NOTE: This lock implementation is extremely simple but should be reliable
#       across all platforms. It does *not* support locking a script with
#       symlinks or multiple hardlinks as there's no portable way of doing so.
#       If the lock was acquired it's automatically released on script exit.
lock_init() {
    local lock_dir
    if [[ $1 = 'system' ]]; then
        lock_dir="/tmp/$script_name.lock"
    elif [[ $1 = 'user' ]]; then
        lock_dir="/tmp/$script_name.$UID.lock"
    else
        script_exit 'Missing or invalid argument to lock_init()!' 2
    fi

    if mkdir "$lock_dir" 2> /dev/null; then
        readonly script_lock="$lock_dir"
        verbose_print "Acquired script lock: $script_lock"
    else
        script_exit "Unable to acquire script lock: $lock_dir" 2
    fi
}


# DESC: Pretty print the provided string
# ARGS: $1 (required): Message to print (defaults to a green foreground)
#       $2 (optional): Colour to print the message with. This can be an ANSI
#                      escape code or one of the prepopulated colour variables.
#       $3 (optional): Set to any value to not append a new line to the message
# OUTS: None
pretty_print() {
    if [[ $# -lt 1 ]]; then
        script_exit 'Missing required argument to pretty_print()!' 2
    fi

    if [[ -z ${no_colour-} ]]; then
        if [[ -n ${2-} ]]; then
            printf '%b' "$2"
        else
            printf '%b' "$fg_green"
        fi
    fi

    # Print message & reset text attributes
    if [[ -n ${3-} ]]; then
        printf '%s%b' "$1" "$ta_none"
    else
        printf '%s%b\n' "$1" "$ta_none"
    fi
}


# DESC: Only pretty_print() the provided string if verbose mode is enabled
# ARGS: $@ (required): Passed through to pretty_pretty() function
# OUTS: None
verbose_print() {
    if [[ -n ${verbose-} ]]; then
        pretty_print "$@"
    fi
}


# DESC: Combines two path variables and removes any duplicates
# ARGS: $1 (required): Path(s) to join with the second argument
#       $2 (optional): Path(s) to join with the first argument
# OUTS: $build_path: The constructed path
# NOTE: Heavily inspired by: https://unix.stackexchange.com/a/40973
build_path() {
    if [[ $# -lt 1 ]]; then
        script_exit 'Missing required argument to build_path()!' 2
    fi

    local new_path path_entry temp_path

    temp_path="$1:"
    if [[ -n ${2-} ]]; then
        temp_path="$temp_path$2:"
    fi

    new_path=
    while [[ -n $temp_path ]]; do
        path_entry="${temp_path%%:*}"
        case "$new_path:" in
            *:"$path_entry":*) ;;
                            *) new_path="$new_path:$path_entry"
                               ;;
        esac
        temp_path="${temp_path#*:}"
    done

    # shellcheck disable=SC2034
    build_path="${new_path#:}"
}


# DESC: Check a binary exists in the search path
# ARGS: $1 (required): Name of the binary to test for existence
#       $2 (optional): Set to any value to treat failure as a fatal error
# OUTS: None
check_binary() {
    if [[ $# -lt 1 ]]; then
        script_exit 'Missing required argument to check_binary()!' 2
    fi

    if ! command -v "$1" > /dev/null 2>&1; then
        if [[ -n ${2-} ]]; then
            script_exit "Missing dependency: Couldn't locate $1." 1
        else
            verbose_print "Missing dependency: $1" "${fg_red-}"
            return 1
        fi
    fi

    verbose_print "Found dependency: $1"
    return 0
}


# DESC: Validate we have superuser access as root (via sudo if requested)
# ARGS: $1 (optional): Set to any value to not attempt root access via sudo
# OUTS: None
check_superuser() {
    local superuser test_euid
    if [[ $EUID -eq 0 ]]; then
        superuser=true
    elif [[ -z ${1-} ]]; then
        if check_binary sudo; then
            pretty_print 'Sudo: Updating cached credentials ...'
            if ! sudo -v; then
                verbose_print "Sudo: Couldn't acquire credentials ..." \
                              "${fg_red-}"
            else
                test_euid="$(sudo -H -- "$BASH" -c 'printf "%s" "$EUID"')"
                if [[ $test_euid -eq 0 ]]; then
                    superuser=true
                fi
            fi
        fi
    fi

    if [[ -z ${superuser-} ]]; then
        verbose_print 'Unable to acquire superuser credentials.' "${fg_red-}"
        return 1
    fi

    verbose_print 'Successfully acquired superuser credentials.'
    return 0
}

# DESC: Run the requested command as root (via sudo if requested)
# ARGS: $1 (optional): Set to zero to not attempt execution via sudo
#       $@ (required): Passed through for execution as root user
# OUTS: None
run_as_root() {
    if [[ $# -eq 0 ]]; then
        script_exit 'Missing required argument to run_as_root()!' 2
    fi

    local try_sudo
    if [[ ${1-} =~ ^0$ ]]; then
        try_sudo=true
        shift
    fi

    if [[ $EUID -eq 0 ]]; then
        "$@"
    elif [[ -z ${try_sudo-} ]]; then
        sudo -H -- "$@"
    else
        script_exit "Unable to run requested command as root: $*" 1
    fi
}
