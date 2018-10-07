# set -e
# set -o pipefail

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

function error_exit
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

function success_exit
{
    echo "${1:-"Completed"}" 1>&2
    exit 0
}

function eval_command() {
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

rome_installed() {
  [-x "$(command -v rome)"]
}

rome_install() {
  if rome_installed; then
    echo "Rome already installed"
    brew outdated rome || brew upgrade rome
    return 0
  fi

  if ! brew_installed; then
    echo "warn: Cannot install Rome withouth Homebrew"
    return 0
  fi

  echo "Rome for Carthage not installed."
  echo "Installing..."
  if [ brew install blender/homebrew-tap/rome ]; then
    echo "Rome for Carthage installed."
    return 0
  else
    echo "Rome for Carthage install failed."
    return 1
  fi
}

brew_installed() {
  [ -x "$(command -v brew)" ]
  return
}

{
  function cleanup {
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
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  else
    echo "Script not in interactive shell. Prompting for user input via Apple Script."
    
    read -r -d '' local MSG << EOM
Warning Homebrew is not installed!

Homebrew is a command line based software package manager and as is required to install and run 'Carthage' and 'Fastlane'.

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
    brew outdated carthage || brew upgrade carthage
    #rome_install
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

carthage_installed() {
  [ -x "$(command -v carthage)" ]
  return
}

carthage_install() {
  if carthage_installed; then
    return 0
  else
    echo "Carthage not installed. Continuing to install it."
  fi

  if ! brew_installed; then
    brew_install
  fi

  if brew_installed; then
      echo "Installing carthage via homebrew"
      brew install carthage
  else
    error_exit "Carthage is required to build this application. It can be automatically installed during the build proccess but that requires having Homebrew for OS X installed first."
  fi
}

github_connection_test() {
  nc -zw1 github.com 443 > /dev/null
  return
}

function lockfile_waithold()
{
  local LOCK_NAME=${1:-"provenance"}
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

 function lockfile_release()
 {
  local LOCK_NAME=${1:-"provenance"}
  local LOCK_FILE="/tmp/$LOCK_NAME.lock"

  echo "🔑 : Releasing lock $LOCK_FILE"
  if [ -f $LOCK_FILE ]; then
    rm -f "$LOCK_FILE"
  fi
 }