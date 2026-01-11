# Known Issues

This document tracks known issues and limitations in XInterview2 version 0.1.0-baseline.

## Non-Blocking Issues

### Swift 6 Sendable Warnings

**Location:** `XInterview2/Data/Networking/DefaultHTTPClient.swift`  
**Severity:** Low (warning only, doesn't affect functionality)  
**Description:**  
The HTTPClient protocol's `request` method has a Swift 6 Sendable warning for the `responseType` parameter (generic type `T.Type`). This is because generic type parameters are not automatically Sendable.

**Example warning:**
```
/Users/xmaster/Developer/iOS/XInterview2/XInterview2/Data/Networking/DefaultHTTPClient.swift:17:10: warning: non-Sendable parameter type 'T.Type' cannot be sent from caller of protocol requirement 'request(endpoint:method:body:headers:responseType:)' into main actor-isolated implementation; this is an error in the Swift 6 language mode
```

**Impact:** None - Build succeeds, app runs correctly.

**Future Fix:** 
- Mark generic type constraints as Sendable in the HTTPClient protocol
- Or suppress the warning if appropriate for Swift 5.9 compatibility

---

### Voice Detection Sensitivity

**Location:** `XInterview2/Data/Audio/VoiceDetector.swift`  
**Severity:** Low (configurable workaround exists)  
**Description:**  
Voice activity detection may have varying accuracy depending on:
- Background noise level
- Microphone quality
- User's speaking volume
- Room acoustics

**Symptoms:**
- False positives: Speech detected when not speaking (background noise)
- False negatives: Speech not detected when user is speaking (soft voice)

**Workaround:**
Users can adjust voice threshold in Settings:
- **Increase threshold** (move slider right) for noisy environments
- **Decrease threshold** (move slider left) for quiet environments or soft-spoken users
- Valid range: 0.05 (very sensitive) to 0.5 (least sensitive)
- Default: 0.5

**Future Fix:**
- Implement streaming VAD (Voice Activity Detection) from WebRTC
- Add automatic calibration on first use
- Add noise suppression before VAD
- Implement adaptive threshold based on user's voice patterns

---

### macOS Audio System Logs

**Location:** System logs (not app logs)  
**Severity:** Info (harmless system messages)  
**Description:**  
Some Core Audio warnings appear in system logs during audio operations:

```
AppleUSBAudioEngine:Unknown Manufacturer:Unknown USB Audio Device:...: Abandoning I/O cycle because reconfig pending
HALC_ProxyIOContext.cpp:1623  HALC_ProxyIOContext::IOWorkLoop: skipping cycle due to overload
```

**Impact:** None - These are informational messages from macOS Core Audio subsystem and do not affect app functionality.

**Future Fix:** None required - this is normal macOS behavior during audio session reconfiguration.

---

## Potential Future Improvements

### Audio Latency

**Description:** There may be perceptible delay between user speaking and AI response due to:
- Whisper transcription latency (~1-3 seconds)
- Chat API processing (~0.5-2 seconds)
- TTS generation (~1-2 seconds)

**Total latency:** ~2.5-7 seconds from end of user speech to start of AI response

**Future Improvements:**
- Use streaming Whisper API (when available) for real-time transcription
- Cache common responses
- Use faster TTS voices if latency is critical

### Conversation Continuity

**Description:** If the user speaks during TTS playback, the response is cut off immediately. This may feel abrupt.

**Current Behavior:**
- User interrupts AI → TTS stops immediately → Voice detection begins → User speech transcribed

**Future Improvement:**
- Add a small "fade out" when interrupted for smoother transition
- Or require explicit "interrupt" gesture (e.g., double-tap)

### Session Persistence

**Description:** Transcript and session data are not persisted between app launches.

**Current Behavior:**
- Transcript clears when app closes
- No way to review past interviews

**Future Enhancement:**
- Save sessions to disk (JSON files)
- Add session history view
- Allow exporting transcripts as text/PDF
- Add search through past sessions

---

## Resolved Issues

The following issues have been resolved in v0.1.0-baseline:

### ✅ TTS Opening Message Interrupted
**Fixed in:** Phase 17 & 19  
**Issue:** Opening AI greeting was immediately cancelled by voice detection  
**Solution:** Added `skipSpeechCheck` parameter to make opening message non-interruptible

### ✅ Transcription Cancellation Error Dialog
**Fixed in:** Phase 20  
**Issue:** "The operation couldn't be completed" error appeared when user spoke during transcription  
**Solution:** Added `HTTPError.requestCancelled` handling to silently ignore expected cancellations

### ✅ iOS-Specific AVAudioSession on macOS
**Fixed in:** Multiple phases  
**Issue:** App tried to use iOS-only `AVAudioSession` on macOS  
**Solution:** Added platform-specific compilation checks (`#if os(iOS)` vs `#if os(macOS)`)

---

## Reporting Issues

When reporting new issues, please include:
1. macOS version
2. XInterview2 version (git tag or commit hash)
3. Steps to reproduce
4. Expected behavior
5. Actual behavior
6. Any error messages or logs
