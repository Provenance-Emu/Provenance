#!/bin/bash

# Development
# openssl aes-256-cbc -k "$SECURITY_PASSWORD" -in scripts/certs/development-cert.cer.enc -d -a -out scripts/certs/development-cert.cer
# openssl aes-256-cbc -k "$SECURITY_PASSWORD" -in scripts/certs/development-key.p12.enc -d -a -out scripts/certs/development-key.p12
# openssl aes-256-cbc -k "$SECURITY_PASSWORD" -in scripts/provisioning-profile/profile-development-olympus.mobileprovision.enc -d -a -out scripts/provisioning-profile/profile-development-olympus.mobileprovision
# # Distribution
# openssl aes-256-cbc -k "$SECURITY_PASSWORD" -in scripts/certs/distribution-cert.cer.enc -d -a -out scripts/certs/distribution-cert.cer
# openssl aes-256-cbc -k "$SECURITY_PASSWORD" -in scripts/certs/distribution-key.p12.enc -d -a -out scripts/certs/distribution-key.p12
# openssl aes-256-cbc -k "$SECURITY_PASSWORD" -in scripts/provisioning-profile/profile-distribution-olympus.mobileprovision.enc -d -a -out scripts/provisioning-profile/profile-distribution-olympus.mobileprovision

# Create custom keychain
# security create-keychain -p $CUSTOM_KEYCHAIN_PASSWORD ios-build.keychain
# # Make the ios-build.keychain default, so xcodebuild will use it
# security default-keychain -s ios-build.keychain
# # Unlock the keychain
# security unlock-keychain -p $CUSTOM_KEYCHAIN_PASSWORD ios-build.keychain
# # Set keychain timeout to 1 hour for long builds
# # see here
# security set-keychain-settings -t 3600 -l ~/Library/Keychains/ios-build.keychain

#security import ./scripts/certs/AppleWWDRCA.cer -k ios-build.keychain -A
#security import ./scripts/certs/development-cert.cer -k ios-build.keychain -A
#security import ./scripts/certs/development-key.p12 -k ios-build.keychain -P $SECURITY_PASSWORD -A
#security import ./scripts/certs/distribution-cert.cer -k ios-build.keychain -A
#security import ./scripts/certs/distribution-key.p12 -k ios-build.keychain -P $SECURITY_PASSWORD -A
# Fix for OS X Sierra that hungs in the codesign step
# security set-key-partition-list -S apple-tool:,apple: -s -k $SECURITY_PASSWORD ios-build.keychain > /dev/null

if [[ "$TRAVIS_PULL_REQUEST" != "false" ]]; then
  echo "This is a pull request. No deployment will be done."
  exit 0
fi

# Scp Uploader
echo "Decoding key"
echo "${SCP_KEY_ENCODED}" | base64 --decode >/tmp/sftp_rsa
chmod 600 /tmp/sftp_rsa

echo "Starting SSH Agent"
eval "$(ssh-agent -s)" #start the ssh agent

echo "Adding SSH Key"
ssh-add /tmp/sftp_rsa

DEST_DIR="${SCP_DIR}/${TRAVIS_BRANCH}/\`${TRAVIS_COMMIT:0:7}\`/${APP_NAME}.ipa"

echo "Creating destination directory"
ssh ${SCP_SERVER} 'mkdir -p "${DEST_DIR}"'

SOURCE_FILE="@$OUTPUTDIR/$APP_NAME.ipa"
echo "Copy ${SOURCE_FILE} to ${DEST_DIR}"
scp -i /tmp/sftp_rsa  ${SCP_USER}@${SCP_SERVER}:"${DEST_DIR}"

echo "Removing temporary SSH key"
rm /tmp/sftp_rsa

# curl --ftp-create-dirs -T filename --key /tmp/sftp_rsa sftp://${SFTP_USER}:${SFTP_PASSWORD}@example.com/directory/filename

# HockeyApp Uploader
# curl https://rink.hockeyapp.net/api/2/apps/$HOCKEY_APP_ID/app_versions \
#   -F status="2" \
#   -F notify="0" \
#   -F notes="$RELEASE_NOTES" \
#   -F notes_type="0" \
#   -F ipa="@$OUTPUTDIR/$APP_NAME.ipa" \
#   -F dsym="@$OUTPUTDIR/$APP_NAME.app.dSYM.zip" \
#   -H "X-HockeyAppToken: $HOCKEY_APP_TOKEN"

# Test Fairy upload
# curl -v -s http://app.testfairy.com/api/upload \
#  -F api_key=$TESTFAIRY_API_KEY \
#  -F file=@build/Products/IPA/restcomm-olympus.ipa \
#  -F video=wifi \
#  -F max-duration=10m \
#  -F comment="Comment for .ipa shown in TestFairy" \
#  -F testers-groups= \
#  -F auto-update=off \
#  -F notify=off \
#  -F instrumentation=off \
#  -A "TestFairy iOS Command Line Uploader 2.1"
echo "Done."
