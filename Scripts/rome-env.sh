export AWS_ACCESS_KEY_ID="AKIA4W6SQJLMQ2ODCCN6"
export AWS_SECRET_ACCESS_KEY="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"
export AWS_REGION="us-east-1"

SWIFT_VERSION=`swift --version | head -1 | sed 's/.*\((.*)\).*/\1/' | tr -d "()" | tr " " "-"`
echo "Swift version: ${SWIFT_VERSION}"