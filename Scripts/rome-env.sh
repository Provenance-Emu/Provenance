export AWS_ACCESS_KEY_ID="M2B65BPG5JRKHIC8RAKX"
export AWS_SECRET_ACCESS_KEY="R1pwhbv7foHK88VDgq1cZ3jlVi2YS6PFv9ueZi4p"
export AWS_REGION="us-east-1"
export AWS_ENDPOINT="http://provenance-emu.app/minio/"

SWIFT_VERSION=`swift --version | head -1 | sed 's/.*\((.*)\).*/\1/' | tr -d "()" | tr " " "-"`

DIRECTORY="carthage"
CACHE_PREFIX="${SWIFT_VERSION}"

echo "Swift version: ${SWIFT_VERSION}. Prefix ${CACHE_PREFIX}"