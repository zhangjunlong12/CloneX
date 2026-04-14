# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CloneX is an AI-powered personal assistant that records user device operations, understands intent, and replays actions. Phase 1 targets Android with basic recording, intent analysis, and playback functionality.

## Development Commands

```bash
# Flutter SDK location
export PATH="$PATH:$HOME/development/flutter/bin"

# Install dependencies
flutter pub get

# Code analysis
flutter analyze

# Run on connected device/emulator
flutter run

# Build debug APK
flutter build apk --debug

# Build release APK
flutter build apk --release
```

## Architecture

### Flutter (Dart) Layer
- **State Management**: Riverpod (`flutter_riverpod`)
- **Local Storage**: SQLite via `sqflite` package
- **UI**: Material Design 3 with custom theme (blue primary color #3B82F6)

### Key Modules

| Module | Purpose |
|--------|---------|
| `lib/models/` | Data models: `Operation`, `Task`, `IntentAnalysis` |
| `lib/services/` | Business logic: `StorageService`, `IntentService`, `PlaybackService` |
| `lib/providers/` | Riverpod state providers |
| `lib/screens/` | UI screens: `HomeScreen`, `RecordingScreen`, `TaskDetailScreen` |

### Android Native Layer
- **AccessibilityService** (`CloneXAccessibilityService.kt`): Handles gesture dispatching and event monitoring
- **Method Channel**: `com.clonex/automation` - Bridge between Flutter and Android automation
- **Shell Fallback** (`ShizukuPlugin.kt`): Shell-level input injection via `su` or `input` commands
- **Operations**: tap, longPress, swipe, input, back, home, scroll

### Data Flow
```
User Action → AccessibilityService → Operation Model → StorageService (SQLite)
                                    ↓
                              IntentService (pattern analysis)
                                    ↓
PlaybackService → MethodChannel → CloneXAccessibilityService → Gesture Dispatch
                                              ↓
                                    ShizukuPlugin (Shell fallback)
```

## Important Notes

- The accessibility service requires user to grant "Accessibility" permission on Android
- Intent analysis is rule-based pattern matching (Phase 1) - no AI model integration yet
- Storage uses SQLite with a single `tasks` table storing operations as JSON

## Gesture Injection Methods

CloneX uses multiple methods for gesture injection (in order of priority):

1. **Shell Command** (`su input tap/swipe`) - Requires root or Shizuku
2. **AccessibilityService.dispatchGesture()** - Works without special permissions but limited to own app window

## Shizuku Configuration Guide

Shizuku enables shell-level permissions for gesture injection without root.

### Installation Steps

1. **Download Shizuku APK**
   - From GitHub: https://github.com/RikkaApps/Shizuku/releases
   - Or search "Shizuku" in app stores

2. **Grant ADB Permissions (One-time Setup)**

   **For Android 11+ (Recommended)**:
   - Open Shizuku app
   - Go to "Developer Options" → "Wireless Debugging"
   - Enable "Wireless debugging"
   - Copy the pairing code
   - In Shizuku, tap "Start with ADB" and enter pairing code

   **For Android 10 and below**:
   - Enable USB debugging on device
   - Connect device to PC
   - Run via ADB: `adb shell sh /sdcard/Android/data/moe.shizuku.privileged.api/start.sh`

3. **Grant Shizuku Permission to CloneX**
   - Open Shizuku app
   - Tap "Grant permission" or use terminal: `adb shell shizuku grant <package_name>`
   - CloneX package name: `com.clonex.clonex`

4. **Verify Shizuku Status**
   - In CloneX app, go to task detail and tap "Start Playback"
   - If Shizuku is connected, it will show "Using Shizuku permission execution"

### Shizuku Troubleshooting

| Problem | Solution |
|---------|---------|
| "Wireless debugging not available" | Enable in Developer Options |
| Shizuku connection drops | Re-run the ADB pairing process |
| "Permission denied" | Re-grant permission in Shizuku app |
| App not responding | Restart Shizuku app and CloneX |

### Alternative: Root Device

If device is rooted, CloneX can use `su` directly:
```bash
# Test if su works
su -c "input tap 500 500"
```

## Android Configuration

### Min SDK
- Minimum SDK: 24 (Android 7.0)
- Target SDK: Latest

### Required Permissions
- `INTERNET` - For app updates
- `QUERY_ALL_PACKAGES` - For package management
- `FOREGROUND_SERVICE` - For background operation
- `BIND_ACCESSIBILITY_SERVICE` - For accessibility service

### Accessibility Service
Located at: `android/app/src/main/kotlin/com/clonex/clonex/CloneXAccessibilityService.kt`

Configure in: `android/app/src/main/res/xml/accessibility_service_config.xml`

User must enable in: Settings → Accessibility → CloneX
