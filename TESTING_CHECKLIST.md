# Audio Download & Playback Testing Checklist

## Download Functionality

### Basic Downloads
- [ ] Download an episode from episode list
- [ ] Download progress shows correctly
- [ ] Download completes successfully
- [ ] Downloaded file appears in Downloads list
- [ ] Downloaded indicator shows on episode row
- [ ] Cancel download mid-way
- [ ] Resume paused download
- [ ] Delete downloaded episode

### Download States
- [ ] Not downloaded state displays correctly
- [ ] Queued state shows waiting indicator
- [ ] Downloading shows progress ring
- [ ] Downloaded shows checkmark
- [ ] Failed shows error icon and message
- [ ] Paused state displays correctly

### Network Conditions
- [ ] WiFi-only download waits for WiFi
- [ ] Cellular download works when enabled
- [ ] Download resumes after network loss
- [ ] Multiple simultaneous downloads work
- [ ] Download queue management works correctly

### Error Handling
- [ ] Invalid URL shows error
- [ ] Network error shows retry option
- [ ] Disk space error handled gracefully
- [ ] Server error (404, 500) handled properly

## Playback Functionality

### Basic Playback
- [ ] Play episode from list
- [ ] Play/pause works correctly
- [ ] Seek bar updates smoothly
- [ ] Skip forward 30s works
- [ ] Skip backward 15s works
- [ ] Playback rate changes (0.5x - 3x)
- [ ] Episode completes and marks as played

### Playback Sources
- [ ] Stream episode (not downloaded)
- [ ] Play downloaded episode
- [ ] Switch between streaming and downloaded
- [ ] Play after partial download completes

### Player UI
- [ ] Full-screen player displays episode info
- [ ] Artwork loads correctly
- [ ] Time display shows correctly
- [ ] Remaining time calculates properly
- [ ] Progress bar reflects playback position
- [ ] Mini player shows at bottom
- [ ] Mini player displays correct info
- [ ] Tap mini player opens full player

### Playback Position
- [ ] Position saves every 5 seconds
- [ ] Position restores on app restart
- [ ] Position saves when backgrounding
- [ ] Position updates in database
- [ ] In-progress episodes show correct position

## Background Audio

### Audio Session
- [ ] Audio plays in background
- [ ] Audio continues after screen lock
- [ ] Audio session handles interruptions
- [ ] Phone call pauses audio
- [ ] Phone call ending resumes audio
- [ ] Alarm interruption handled
- [ ] Siri interruption handled

### Now Playing Integration
- [ ] Lock screen shows episode info
- [ ] Lock screen shows artwork
- [ ] Lock screen play/pause works
- [ ] Lock screen skip forward works
- [ ] Lock screen skip backward works
- [ ] Lock screen seek works
- [ ] Control Center shows info
- [ ] Control Center controls work
- [ ] CarPlay integration (if available)

### Background Downloads
- [ ] Download continues in background
- [ ] App restart resumes downloads
- [ ] Background session handles completion
- [ ] Multiple background downloads work

## State Management

### Database
- [ ] Episode download status persists
- [ ] Playback position persists
- [ ] Download progress persists
- [ ] Migration runs successfully
- [ ] No data loss on updates

### Memory Management
- [ ] No memory leaks during playback
- [ ] No memory leaks during downloads
- [ ] Large files handled efficiently
- [ ] Many episodes in list perform well

## Edge Cases

### File Management
- [ ] Episode with special characters in filename
- [ ] Episode with very long title
- [ ] Episode with no artwork
- [ ] Episode with invalid MIME type
- [ ] Orphaned files cleaned up correctly

### Network Edge Cases
- [ ] Switch from WiFi to cellular mid-download
- [ ] Airplane mode during download
- [ ] VPN connection changes
- [ ] Slow/unstable connection
- [ ] Redirect URLs handled

### Playback Edge Cases
- [ ] Very short episode (< 1 minute)
- [ ] Very long episode (> 5 hours)
- [ ] Episode with no duration metadata
- [ ] Corrupted audio file
- [ ] Invalid audio format

### UI Edge Cases
- [ ] Multiple rapid play/pause taps
- [ ] Rapid seek operations
- [ ] Rotate device during playback
- [ ] Switch episodes rapidly
- [ ] Delete episode while playing
- [ ] Download same episode twice

## Performance

### Responsiveness
- [ ] UI remains responsive during downloads
- [ ] UI remains responsive during playback
- [ ] Scrolling smooth with many episodes
- [ ] No lag when switching views
- [ ] Fast app launch time

### Resource Usage
- [ ] Battery usage reasonable
- [ ] CPU usage reasonable during playback
- [ ] Network usage efficient
- [ ] Disk space tracked correctly
- [ ] No excessive logging

## Accessibility

### VoiceOver
- [ ] All buttons have labels
- [ ] Player controls accessible
- [ ] Download button states clear
- [ ] Progress indicators announced

## Testing Notes

### Required Permissions
- Background audio capability in Xcode
- Background fetch capability for downloads
- Media playback category in audio session

### Test Environment
- Test on real device (not just simulator)
- Test with headphones
- Test with Bluetooth devices
- Test with different network conditions
- Test with low battery mode
- Test with Do Not Disturb enabled

### Test Data
- Prepare test episodes of various:
  - Durations (short, medium, long)
  - File sizes (small, large)
  - Formats (MP3, M4A, etc.)
  - Network sources (different CDNs)

## Known Limitations (MVP)

- No chapters support yet
- No sleep timer yet
- No variable speed with pitch correction
- No silence removal yet
- No auto-download new episodes
- No video podcast support
- No CarPlay custom UI
- No widgets yet
- No Watch app yet

## Success Criteria

The implementation is considered successful if:
1. ✅ Episodes can be downloaded reliably
2. ✅ Downloads can be cancelled/resumed
3. ✅ Downloaded episodes play from local storage
4. ✅ Non-downloaded episodes stream correctly
5. ✅ Playback position is saved and restored
6. ✅ Background audio works
7. ✅ Lock screen controls work
8. ✅ No crashes during normal usage
9. ✅ Database migrations work correctly
10. ✅ File storage is managed properly
