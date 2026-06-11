# KuroPlayer

A macOS music player — SoundCloud + YouTube Music unified, Last.fm scrobbling, Kurokula dark theme.

## Features

- **Unified Music Library** — Search and play from YouTube Music and SoundCloud in one place
- **YouTube Music** — Full track streaming via yt-dlp (no Premium needed)
- **SoundCloud** — Native AVPlayer streaming
- **Last.fm Scrobbling** — Automatic scrobbling with "now playing" updates
- **Kurokula Theme** — Dark charcoal UI with warm beige, crimson accent, and neon pops
- **Smart Queue** — Shuffle, repeat modes, and seamless track transitions

## Setup

### 1. Get API Keys

You'll need API credentials for the services you want full access to:

#### SoundCloud
1. Go to [SoundCloud Developers](https://developers.soundcloud.com/)
2. Register a new app
3. Set redirect URI: `kuroplayer://soundcloud-callback`
4. Copy your Client ID and Client Secret

#### YouTube Music
- **Search & streaming works immediately** via yt-dlp — no API key needed
- Optional: Google OAuth for library/playlist access

#### Last.fm
1. Go to [Last.fm API](https://www.last.fm/api/account/create)
2. Create a new API account
3. Copy your API Key and Shared Secret

### 2. Add Credentials to Code

Open these files and replace the placeholder values:

**SoundCloudAuth.swift:**

**SoundCloudAuth.swift:**
```swift
private let clientID = "YOUR_SOUNDCLOUD_CLIENT_ID"
private let clientSecret = "YOUR_SOUNDCLOUD_CLIENT_SECRET"
```

**LastFmAuth.swift:**
```swift
private let apiKey = "YOUR_LASTFM_API_KEY"
private let apiSecret = "YOUR_LASTFM_API_SECRET"
```

### 3. Build & Run

```bash
cd ~/Documents/projects/KuroPlayer
swift build
swift run
```

Or open in Xcode:
```bash
# Generate Xcode project (if you have XcodeGen)
# Or open Package.swift directly in Xcode
open Package.swift
```

## Project Structure

```
KuroPlayer/
├── Sources/KuroPlayer/
│   ├── App/
│   │   └── KuroPlayerApp.swift          # Main entry point
│   ├── Models/
│   │   ├── Track.swift                  # Track model
│   │   ├── Playlist.swift               # Playlist model
│   │   └── PlaybackState.swift          # Playback state
│   ├── Providers/
│   │   ├── MusicProviderProtocol.swift  # Provider interface
│   │   ├── YouTubeMusicProvider.swift   # YouTube Music (yt-dlp)
│   │   ├── SoundCloudProvider.swift     # SoundCloud implementation
│   │   └── ProviderRegistry.swift       # Provider manager
│   ├── Playback/
│   │   └── PlaybackEngine.swift         # Audio player
│   ├── Scrobbling/
│   │   └── LastFmScrobbler.swift        # Last.fm integration
│   ├── Auth/
│   │   ├── AuthManager.swift            # OAuth coordinator
│   │   ├── YouTubeMusicAuth.swift       # YouTube Music OAuth
│   │   ├── SoundCloudAuth.swift         # SoundCloud OAuth
│   │   └── LastFmAuth.swift             # Last.fm auth
│   ├── UI/
│   │   ├── Theme/
│   │   │   └── KurokulaTheme.swift      # Color scheme
│   │   └── Views/
│   │       ├── ContentView.swift        # Main layout
│   │       ├── SidebarView.swift        # Navigation
│   │       ├── PlayerBarView.swift      # Playback controls
│   │       ├── LibraryView.swift        # Library browser
│   │       ├── SearchView.swift         # Search interface
│   │       └── SettingsView.swift       # Settings & auth
│   └── ViewModels/
│       └── PlayerViewModel.swift        # State management
```

## Color Scheme (Kurokula)

- **Background:** `#131515` (dark charcoal)
- **Foreground:** `#dfcfc2` (warm beige)
- **Accent:** `#791c1c` (deep crimson)
- **Secondary:** `#fff600` (neon yellow)
- **Success:** `#aeffa4` (neon green)
- **Error:** `#c35951` (soft red)
- **Gray:** `#505151` (medium gray)
- **White:** `#feffff` (pure white)

## Notes

- Spotify playback requires Spotify Premium (uses Web Playback SDK)
- SoundCloud streams use direct HTTP URLs via AVPlayer
- Last.fm scrobbles at 50% or 4 minutes (whichever comes first)
- "Now Playing" updates sent after 30 seconds

## Next Steps

- [ ] Add Spotify Web Playback SDK integration
- [ ] Implement playlist creation/management
- [ ] Add local file support
- [ ] Keyboard shortcuts
- [ ] Menu bar mini player
- [ ] Additional providers (Apple Music, YouTube Music)

## License

MIT
