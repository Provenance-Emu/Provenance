# CloudKit Setup for Provenance tvOS Sync

This document provides instructions for setting up CloudKit for Provenance's tvOS sync functionality.

## Overview

Provenance uses CloudKit for synchronizing game data between tvOS devices, while continuing to use iCloud Documents for iOS and macOS devices. This hybrid approach allows for the most efficient sync mechanism on each platform.

## CloudKit Container Setup

1. Log in to the [Apple Developer Portal](https://developer.apple.com)
2. Navigate to "Certificates, Identifiers & Profiles"
3. Select "Identifiers" from the sidebar
4. Find your Provenance app identifier and click on it
5. Scroll down to the "iCloud" section and ensure it's enabled
6. Under iCloud, check "CloudKit" and click "Configure"
7. Create a new container or select an existing one (e.g., `iCloud.com.provenance-emu.provenance`)
8. Save your changes

## CloudKit Dashboard Setup

1. Go to the [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard/)
2. Select your CloudKit container
3. Click on "Schema" in the sidebar
4. Create the following record types:

### Record Types

#### 1. File

This record type represents a file in CloudKit (ROM, save state, BIOS, etc.)

**Fields:**
- `directory` (String) - Directory containing the file (e.g., "Roms", "Saves", "BIOS")
- `system` (String) - System identifier or subdirectory (e.g., "SNES", "NES")
- `filename` (String) - Filename of the file
- `fileData` (Asset) - File data as a CKAsset
- `lastModified` (Date) - Last modified date
- `md5` (String) - MD5 hash of the file (if available)
- `gameID` (String) - ID of the game this file belongs to (for save states)
- `saveStateID` (String) - ID of the save state this file belongs to (for save states)

#### 2. Game

This record type represents metadata about a game

**Fields:**
- `title` (String) - Game title
- `systemIdentifier` (String) - System identifier
- `romPath` (String) - ROM path
- `md5Hash` (String) - MD5 hash of the ROM
- `description` (String) - Game description
- `region` (String) - Game region
- `developer` (String) - Game developer
- `publisher` (String) - Game publisher
- `genre` (String) - Game genre
- `releaseDate` (Date) - Game release date

#### 3. SaveState

This record type represents metadata about a save state

**Fields:**
- `description` (String) - Save state description
- `timestamp` (Date) - Save state timestamp
- `gameID` (String) - Game ID this save state belongs to
- `coreIdentifier` (String) - Core identifier
- `coreVersion` (String) - Core version
- `screenshot` (Asset) - Screenshot data as a CKAsset

### Indexes

Create the following indexes to improve query performance:

#### File Record Indexes
- `directory`
- `system`
- `filename`
- `gameID`
- `saveStateID`
- `md5`

#### Game Record Indexes
- `systemIdentifier`
- `md5Hash`
- `title`

#### SaveState Record Indexes
- `gameID`
- `timestamp`

## Security Roles

Ensure that the following security roles are set up:

1. **Public Access**: No access
2. **Private Access**: Full access to all record types

## Testing CloudKit

After setting up CloudKit, you can test it by:

1. Building and running Provenance on a tvOS device or simulator
2. Enabling iCloud sync in the settings
3. Adding a game and verifying it syncs correctly
4. Creating a save state and verifying it syncs correctly

## Troubleshooting

If you encounter issues with CloudKit sync:

1. Check the CloudKit Dashboard for any errors
2. Verify that the correct container is being used
3. Ensure that the app has the necessary entitlements
4. Check the device logs for any CloudKit-related errors

## Additional Resources

- [CloudKit Documentation](https://developer.apple.com/documentation/cloudkit)
- [iCloud Entitlements](https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_developer_icloud-container-identifiers)
- [CloudKit Best Practices](https://developer.apple.com/videos/play/wwdc2016/231/)
