# RetroStatusControlView

A retrowave-styled interactive status view for Provenance that provides real-time feedback on system operations and allows users to control various app features.

## Features

- **Interactive Controls**: Buttons to start/stop web servers, pause/resume imports, and trigger file recovery
- **Real-time Status Updates**: Shows progress for file uploads, downloads, and recovery operations
- **System Statistics**: Displays memory usage and disk space information
- **Retrowave Styling**: Consistent with Provenance's retrowave aesthetic using the existing color palette
- **Expandable Interface**: Collapses to a minimal view when not in use, expands to show detailed controls and information
- **Auto-hide Capability**: Can automatically hide after a period of inactivity

## Components

### RetroStatusControlView

The main view component that displays status information and interactive controls.

### RetroStatusViewModifier

A SwiftUI view modifier that makes it easy to add the RetroStatusControlView to any view in the app.

## Usage

Add the RetroStatusControlView to any SwiftUI view using the view modifier:

```swift
YourView()
    .withRetroStatusView(position: .bottom, autoHide: true, autoHideDelay: 10.0)
```

## Key Improvements

### File Recovery Enhancements

- Prevents duplicate notifications during boot
- Ensures only one recovery session is active at a time
- Provides interactive controls to manage the recovery process
- Shows real-time progress of file recovery operations

### Web Server Management

- Displays web server status (running/stopped)
- Shows server URLs for easy access
- Provides one-tap controls to start/stop servers
- Tracks file upload progress in real-time

### Upload Progress Tracking

- Shows file upload progress with percentage and file size information
- Displays queue length for multiple file uploads
- Provides visual feedback on upload completion

## Implementation Details

- Uses the existing retrowave color palette for consistent styling
- Integrates with the notification system to track various operations
- Provides a unified interface for monitoring and controlling system operations
- Auto-hides to minimize UI clutter when not needed

## Integration Points

The RetroStatusControlView has been integrated into the following key areas of the app:

- ConsolesWrapperView
- HomeView
- ConsoleGamesView

This ensures the status view is accessible from all main navigation areas of the app.
