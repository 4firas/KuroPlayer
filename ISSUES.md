# KuroPlayer — Development Issues

## 2026-06-12 Update (large refactor, untested — built blind on Linux)

Resolved in this pass: #3 (stream URLs re-fetched + short-TTL cached), #10 (search/stream caching + debounce + next-track prefetch), #13 (scrobble timer ignores seeks/stalls), #14 (spinner on play button while loading).

New since the last update:
- **Shared yt-dlp runner** (`Utilities/YtDlp.swift`): binary auto-discovery (Homebrew/MacPorts/usr-local/~/.local), consistent flags, hard timeouts, process termination on task cancellation. Both providers now behave identically.
- **Search debounce** (350 ms) — previously every keystroke spawned two yt-dlp processes.
- **Playlist import**: paste a SoundCloud set or YouTube/YouTube Music playlist URL in Search or the new Playlists view. SoundCloud uses full extraction (flat entries have no titles — the old breakage) and pulls the set's own cover art. Playlists persist in Application Support (`PlaylistStore`).
- **Parametric EQ** (`Audio/`): MTAudioProcessingTap + Apple NBandEQ AudioUnit on the AVPlayer item. Bundled oratory1990/AutoEq presets (peqdb.com format); paste any preset from peqdb.com via Settings. Live updates while playing. Note: needs progressive (non-HLS) streams — format selection prefers `protocol^=http`.
- **Theme system** (`UI/Theme/ThemeManager.swift`): System mode (follows macOS light/dark + system accent) vs Kurokula (default). Secret: 7 clicks on the version number in Settings → About unlock the Kurokula switch after leaving it.
- **Playback engine fixes**: single AVPlayer + `replaceCurrentItem` (the periodic time observer previously died after the first track), end-of-track via `AVPlayerItemDidPlayToEndTime` instead of duration math, repeat-all index wrap, no more stuck "loading" state, shuffle preserves/restores original order, stale play requests can't clobber newer ones.
- **UI**: scrollbars hidden (the "vertical slider on the right"), themed `KuroSlider` replaces stock volume slider, scrubbable progress bar with time labels, shuffle/repeat buttons, queue clear button, standardized headers.

⚠️ None of this has been compiled or run — no Swift toolchain on the dev box. Expect a fix-up pass on first `swift build`. Most likely friction points: MTAudioProcessingTap callback signatures (EQAudioTap.swift) and strict-concurrency diagnostics.

## Project Overview

macOS native music player built with SwiftUI. Unified library across YouTube Music + SoundCloud, Last.fm scrobbling, kurokula dark theme.

**Stack:** Swift 6.4, SwiftUI, AVFoundation, yt-dlp (for YouTube Music streaming), SPM  
**Build:** `bash launch.sh` (builds + wraps in .app bundle + launches)  
**Target:** macOS 13.0+  
**CLI limitation:** No `@State` macro available (missing SwiftUIMacros plugin in Command Line Tools). All state must go through ViewModel `@Published` properties.

---

## 🔴 Critical — Fix First

### 1. No media key support
**Problem:** Mac keyboard play/pause/next/prev buttons do nothing.  
**Fix:** Integrate `MPRemoteCommandCenter` + `MPNowPlayingInfoCenter` in `PlaybackEngine.swift`. Register commands for `.togglePlayPauseCommand`, `.nextTrackCommand`, `.previousTrackCommand`. Update now playing info (title, artist, artwork, duration, elapsed time) on every track change and time update.  
**File:** `Sources/KuroPlayer/Playback/PlaybackEngine.swift`

### 2. No queue persistence
**Problem:** Queue, volume, playback position all lost on restart.  
**Fix:** Serialize current queue + position + volume to a JSON file in Application Support on every change (debounced). Restore on launch. Use `Codable` on `Track` (already conforms).  
**Files:** `Sources/KuroPlayer/Playback/PlaybackEngine.swift`, `Sources/KuroPlayer/Models/`

### 3. yt-dlp stream URLs expire silently
**Problem:** YouTube stream URLs are time-limited (~6hrs). If a track sits in queue, the URL dies before it plays → silent failure.  
**Fix:** Before playing any queued track, re-fetch the stream URL via `getStreamURL(for:)` instead of caching the URL. Or: validate URL freshness before playback and re-fetch if >30min old.  
**Files:** `Sources/KuroPlayer/Providers/YouTubeMusicProvider.swift`, `Sources/KuroPlayer/Playback/PlaybackEngine.swift`

### 4. SoundCloud is dead
**Problem:** SoundCloud shut down public API in 2023. OAuth connect page is broken for new apps. Provider is effectively non-functional.  
**Fix options:**  
- (A) Replace with a different provider (Apple Music, Bandcamp, Tidal)  
- (B) Use unofficial SoundCloud scraping via yt-dlp (it supports soundcloud)  
- (C) Mark as "coming soon" and hide from UI  

**Recommendation:** Option B — yt-dlp already handles SoundCloud URLs. Create a `SoundCloudProvider` that uses yt-dlp the same way YouTube Music does, no API key needed.  
**Files:** `Sources/KuroPlayer/Providers/SoundCloudProvider.swift`, `Sources/KuroPlayer/Auth/SoundCloudAuth.swift`

### 5. No `@State` macro
**Problem:** CLI tools missing `SwiftUIMacros` plugin. `@State` fails at compile time. All local view state must use `@Published` on ViewModel or `@StateObject` wrappers.  
**Workaround:** Already worked around — all state moved to `PlayerViewModel`. But this limits UI flexibility (can't have local hover state, local form state, etc.).  
**Fix:** Either install Xcode (which includes the plugin) or find a way to add the plugin dylib to the CLI toolchain. The dylib exists at `/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/` but `SwiftUIMacros` specifically is missing.

---

## 🟡 Functional Gaps

### 6. YouTube Music = search + stream only
**Problem:** No OAuth = no library, no playlists, no liked tracks. User can search and play but that's it.  
**Fix:** Implement Google OAuth for YouTube Music. Store token, use YouTube Data API v3 for library/playlist access. yt-dlp handles streaming regardless of auth.  
**Files:** `Sources/KuroPlayer/Auth/YouTubeMusicAuth.swift`, `Sources/KuroPlayer/Providers/YouTubeMusicProvider.swift`

### 7. No keyboard shortcuts
**Problem:** No ⌘F to focus search, no spacebar play/pause, no ⌘N/⌘P for next/prev.  
**Fix:** Add `.keyboardShortcut()` modifiers to buttons, or implement a global key event handler. Spacebar should toggle play/pause when app is focused.  
**Files:** `Sources/KuroPlayer/UI/Views/PlayerBarView.swift`, `Sources/KuroPlayer/UI/Views/SearchView.swift`

### 8. No minimize to menu bar
**Problem:** App only lives in Dock. No background/menu bar mode.  
**Fix:** Add `LSUIElement` support or menu bar icon with mini player. Use `NSStatusBar` for menu bar icon. Mini player shows current track + controls.  
**Files:** New `Sources/KuroPlayer/UI/MenuBar/`, modify `KuroPlayerApp.swift`

### 9. No local file support
**Problem:** Can't play downloaded MP3s/FLACs/WAVs.  
**Fix:** Add a `LocalFileProvider` that conforms to `MusicProvider`. Scan user's Music folder, index audio files, create `Track` objects with local file URLs. Use AVPlayer directly (no yt-dlp needed).  
**Files:** New `Sources/KuroPlayer/Providers/LocalFileProvider.swift`

### 10. No offline caching
**Problem:** Every play re-fetches stream URL via yt-dlp (1-3s delay). Repeated searches hit yt-dlp each time.  
**Fix:** Cache search results with TTL (e.g., 30min). For streams, optionally cache audio data to disk for repeated plays.  
**Files:** New `Sources/KuroPlayer/Utilities/Cache.swift`, modify providers

### 11. Playlist CRUD missing
**Problem:** Can read playlists (with auth) but can't create/edit/delete.  
**Fix:** Add methods to `MusicProvider` protocol: `createPlaylist(name:)`, `addTrackToPlaylist(playlist:track:)`, `removeTrackFromPlaylist(playlist:track:)`, `deletePlaylist(playlist:)`. Implement for each provider.  
**Files:** `Sources/KuroPlayer/Providers/MusicProviderProtocol.swift` + each provider

### 12. No drag-reorder queue
**Problem:** Queue is append-only, can't rearrange track order.  
**Fix:** Use SwiftUI's `.onMove` in a List, or implement drag-drop with `.onDrag`/`.onDrop`. Update `PlaybackEngine.queue` accordingly.  
**Files:** New queue view, modify `PlaybackEngine.swift`

### 13. Scrobble timer ignores pause
**Problem:** `ScrobbleTracker` counts elapsed time continuously. If user pauses at 40% and resumes at 50%, it scrobbles prematurely because the 50% threshold was crossed in terms of track position, not actual listen time.  
**Fix:** Track actual listened time (subtract paused duration). Only scrobble after 50% of track duration has been *actively listened to*.  
**Files:** `Sources/KuroPlayer/Playback/PlaybackEngine.swift` (ScrobbleTracker class)

---

## 🟡 UI/UX Polish

### 14. No loading indicator on play
**Problem:** When yt-dlp fetches stream URL (1-3s), UI shows nothing. User thinks the click didn't register.  
**Fix:** Show a spinner or pulsing animation on the play button / progress bar while `status == .loading`. Already have `.loading` state in `PlaybackState` — just need visual indicator.  
**Files:** `Sources/KuroPlayer/UI/Views/PlayerBarView.swift`

### 15. Home page cards do nothing
**Problem:** Track cards on Home have no tap action. They're just decorative.  
**Fix:** Wire up `.onTapGesture` or wrap in Button to play the track.  
**Files:** `Sources/KuroPlayer/UI/Views/ContentView.swift` (TrackCard)

### 16. No "now playing" animation
**Problem:** No visual indicator of what's currently playing anywhere.  
**Fix:** Add an equalizer animation (3 bars bouncing) next to the currently playing track in library/search views. Highlight the active track row.  
**Files:** New `Components/NowPlayingIndicator.swift`, modify `TrackRowContent`

### 17. Error display is an alert popup
**Problem:** Errors show as macOS alert dialogs. Feels jarring.  
**Fix:** Replace with inline toast/banner that auto-dismisses. Show at top of content area.  
**Files:** New `Components/ToastBanner.swift`, modify `ContentView.swift`

### 18. No hover effect on track rows
**Problem:** `TrackRowButtonStyle` gives press animation but no hover background highlight. Tracks feel dead on hover.  
**Fix:** Track hover state in the button style using a `HoverPressTracker` ObservableObject, or use `.onHover` with a background color transition.  
**Files:** `Sources/KuroPlayer/UI/Views/LibraryView.swift` (TrackRowButtonStyle), `Sources/KuroPlayer/UI/Components/LiquidGlassStyle.swift`

### 19. No smooth view transitions
**Problem:** Switching between Home/Search/Library/Settings is instant — no transition animation.  
**Fix:** Wrap the view switcher in ContentView with `.transition(.opacity.combined(with: .move(edge: .trailing)))` and `.animation(.easeInOut(duration: 0.2), value: selectedView)`.  
**Files:** `Sources/KuroPlayer/UI/Views/ContentView.swift`

### 20. No artwork fallback
**Problem:** Missing artwork shows a gray rectangle instead of a music note icon.  
**Fix:** In `AsyncImage` placeholder, show a rounded rectangle with `Image(systemName: "music.note")` centered.  
**Files:** `Sources/KuroPlayer/UI/Views/LibraryView.swift` (TrackRowContent), `PlayerBarView.swift`, `ContentView.swift`

---

## 🔵 Architecture

### 21. PlaybackEngine is a singleton
**Problem:** `static let shared` makes it untestable and hard to mock.  
**Fix:** Convert to a regular class, inject via `@EnvironmentObject`. Create a protocol `PlaybackEngineProtocol` for testing.  
**Files:** `Sources/KuroPlayer/Playback/PlaybackEngine.swift`

### 22. No code signing
**Problem:** App isn't signed. Gatekeeper blocks on other Macs. OAuth callbacks unreliable without bundle ID registration.  
**Fix:** Sign with ad-hoc identity at minimum: `codesign --force --deep --sign - KuroPlayer.app`. Or set up Developer ID if user has Apple Developer account.  
**Files:** Modify `launch.sh`

### 23. No token refresh
**Problem:** SoundCloud/Last.fm tokens expire and never auto-refresh. User must re-auth.  
**Fix:** Add refresh logic in each auth class. Check expiration before each API call. Use `refresh_token` to get new `access_token`.  
**Files:** `Sources/KuroPlayer/Auth/SoundCloudAuth.swift`, `Sources/KuroPlayer/Auth/LastFmAuth.swift`

### 24. No Xcode project
**Problem:** SPM only. `.app` bundle built manually via `launch.sh`. Can't use Xcode debugger, Interface Builder, or Instruments.  
**Fix:** Generate Xcode project with `xcodegen` or create `.xcodeproj` manually. Or just document that Xcode users should `open Package.swift`.  
**Files:** New `project.yml` for xcodegen

### 25. No tests
**Problem:** Zero unit or UI tests.  
**Fix:** Add test target to `Package.swift`. Write tests for: Track parsing, scrobble timing logic, provider registry, state management.  
**Files:** New `Tests/KuroPlayerTests/`

---

## Build & Run

```bash
cd ~/Documents/projects/KuroPlayer
bash launch.sh    # builds + bundles + launches
```

Or just:
```bash
swift build && cp .build/debug/KuroPlayer KuroPlayer.app/Contents/MacOS/ && open KuroPlayer.app
```

## API Keys

Users set keys in-app via **Settings → API Keys**. Stored in UserDefaults. YouTube Music works without any key (uses yt-dlp). SoundCloud and Last.fm need user-provided keys.

## Color Scheme (Kurokula)

All colors in `Sources/KuroPlayer/UI/Theme/KurokulaTheme.swift`. Dark charcoal + warm beige fg + crimson accent + neon yellow/green pops.

## Architecture

```
MusicProvider (protocol)
├── YouTubeMusicProvider  → yt-dlp (search + stream, no auth needed)
├── SoundCloudProvider    → broken (API dead, needs replacement)
└── (LocalFileProvider)   → planned

ProviderRegistry → parallel search across all providers
       ↓
PlaybackEngine → AVPlayer + scrobble tracking
       ↓
LastFmScrobbler → MD5-signed API calls

PlayerViewModel → single source of truth for all UI state
```
