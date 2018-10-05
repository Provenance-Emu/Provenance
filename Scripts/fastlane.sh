DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
. "$DIR/setup_env.sh"

if [ fastlane_installed ] then
  bundle exec fastlane updatePlistForBranch
fi
