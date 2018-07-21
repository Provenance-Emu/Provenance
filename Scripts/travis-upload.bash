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

# Scp Uploader
echo "${SCP_KEY_ENCODED}" | base64 --decode >/tmp/sftp_rsa
chmod 600 /tmp/sftp_rsa
scp -i /tmp/sftp_rsa "@$OUTPUTDIR/$APP_NAME.ipa" $SCP_USER@$SCP_SERVER:$SCP_DIR/$TRAVIS_BRANCH/\`${TRAVIS_COMMIT:0:7}\`/$APP_NAME.ipa
rm /tmp/sftp_rsa
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
