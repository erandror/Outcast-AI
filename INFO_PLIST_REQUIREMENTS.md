# Required Info.plist Configurations

## Background Audio

Add to Info.plist:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>fetch</string>
</array>
```

## App Transport Security

To allow streaming from HTTP sources (if needed):

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <key>NSAllowsArbitraryLoadsInWebContent</key>
    <false/>
</dict>
```

## Privacy Descriptions

```xml
<key>NSAppleMusicUsageDescription</key>
<string>Outcast needs access to control audio playback.</string>
```

## Required Capabilities (Xcode Project Settings)

1. **Background Modes**
   - Audio, AirPlay, and Picture in Picture
   - Background fetch

2. **App Groups** (for future widget/Watch support)
   - group.com.outcast.app

## Audio Session Category

The app is configured to use:
- Category: `.playback`
- Mode: `.spokenAudio`
- Policy: `.longFormAudio`

This provides:
- Background audio playback
- Remote control support
- Now Playing integration
- Smart AirPods integration
- Spoken content optimization
