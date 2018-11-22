set -e
if [[ ( ! -d "RxSwift/.git" ) ]]; then
    git submodule update --init --recursive --force
    cd RxSwift
    git reset origin/master --hard
fi
