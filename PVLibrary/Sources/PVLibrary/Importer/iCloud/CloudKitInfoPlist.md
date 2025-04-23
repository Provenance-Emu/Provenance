# CloudKit Info.plist Configuration

To enable proper CloudKit functionality in Provenance, you need to update the app's Info.plist with the following capabilities:

## Required Background Modes

Add the following background modes to your Info.plist:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

This enables the app to receive and process CloudKit notifications in the background, which is essential for real-time sync.

## CloudKit Container Identifier

Make sure your CloudKit container identifier is properly configured:

```xml
<key>NSUbiquitousContainers</key>
<dict>
    <key>iCloud.com.provenance-emu.provenance</key>
    <dict>
        <key>NSUbiquitousContainerIsDocumentScopePublic</key>
        <true/>
        <key>NSUbiquitousContainerName</key>
        <string>Provenance</string>
        <key>NSUbiquitousContainerSupportedFolderLevels</key>
        <string>Any</string>
    </dict>
</dict>
```

## Capabilities Configuration

In Xcode, you should also enable the following capabilities:

1. **iCloud**: Enable iCloud with CloudKit and iCloud Documents
2. **Background Modes**: Enable "Remote notifications"
3. **Push Notifications**: Enable push notifications

## Testing CloudKit Notifications

To test CloudKit notifications:

1. Make sure you're signed in to iCloud on your test device
2. Enable iCloud sync in the app settings
3. Make changes on one device and verify they appear on another
4. Check the device logs for CloudKit notification handling

## Troubleshooting

If CloudKit notifications aren't working:

1. Verify background modes are properly configured
2. Check that the app has permission to receive notifications
3. Ensure the CloudKit container is properly set up in the developer portal
4. Look for errors in the device logs related to CloudKit or push notifications

## Additional Resources

- [CloudKit Documentation](https://developer.apple.com/documentation/cloudkit)
- [Background Modes Documentation](https://developer.apple.com/documentation/bundleresources/information_property_list/uibackgroundmodes)
- [Push Notifications Documentation](https://developer.apple.com/documentation/usernotifications)
