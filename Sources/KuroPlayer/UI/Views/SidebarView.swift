import SwiftUI

// MARK: - Sidebar Navigation

enum MainView: String, CaseIterable, Identifiable, Hashable {
    case home, search, library, lyrics, queue, likedSongs, settings, playlistDetail
    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:    return "Home"
        case .search:  return "Search"
        case .library: return "Library"
        case .lyrics:  return "Lyrics"
        case .queue:   return "Queue"
        case .likedSongs: return "Liked Songs"
        case .settings: return "Settings"
        case .playlistDetail: return "Playlist"
        }
    }

    var icon: String {
        switch self {
        case .home:    return "house.fill"
        case .search:  return "magnifyingglass"
        case .library: return "music.note.list"
        case .lyrics:  return "text.quote"
        case .queue:   return "list.bullet"
        case .likedSongs: return "heart.fill"
        case .settings: return "gearshape.fill"
        case .playlistDetail: return "music.note.list"
        }
    }
}

enum SidebarSelection: Hashable {
    case view(MainView)
    case playlist(String)
}

class SidebarViewState: ObservableObject {
    @Published var selection: SidebarSelection? = .view(.home)
}

struct SidebarView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @StateObject private var state = SidebarViewState()
    @ObservedObject private var downloadManager = DownloadManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Traffic-light safe area + window drag region
            Color.clear
                .frame(height: 28)
                .contentShape(.rect)
                .onTapGesture {}

            navSection

            // Playlists
            ScrollView(showsIndicators: false) {
                Color.clear.frame(width: 0, height: 0).hideNativeScrollbars()
                VStack(alignment: .leading, spacing: 4) {
                    playlistsSection
                    statusSection
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
            
            Spacer(minLength: 0)

            bottomSection
        }
        .onChange(of: state.selection) { _, new in
            applySelection(new)
        }
    }

    // MARK: Playlists

    private var playlistsSection: some View {
        SidebarSection(title: "Playlists", trailing: {
            Menu {
                Button("New Playlist") {
                    withAnimation(.easeIn(duration: 0.15)) {
                        viewModel.showNewPlaylist = true
                    }
                }
                Button("Import Web Playlist") {
                    withAnimation(.easeIn(duration: 0.15)) {
                        viewModel.showImportPlaylist = true
                    }
                }
                Button("Import Local Files") {
                    viewModel.importLocalFiles()
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .offset(x: 4)
        }) {
            ForEach(viewModel.playlists) { playlist in
                SidebarRow(
                    title: playlist.name,
                    icon: { playlistIcon(for: playlist) },
                    isSelected: state.selection == .playlist(playlist.id),
                    accentOnSelect: false
                ) {
                    state.selection = .playlist(playlist.id)
                    viewModel.selectedPlaylistId = playlist.id
                    viewModel.selectedView = .playlistDetail
                }
                .lineLimit(1)
                .contextMenu {
                    Button("Rename") {
                        viewModel.renameText = playlist.name
                        withAnimation(.easeIn(duration: 0.15)) {
                            viewModel.renamingPlaylistId = playlist.id
                        }
                    }
                    Divider()
                    Button("Delete", role: .destructive) {
                        viewModel.removePlaylist(playlist)
                    }
                }
            }
            
            SidebarRow(
                title: viewModel.isImportingPlaylist ? "Importing..." : "Import Playlist",
                systemIcon: "link",
                glyphSize: 14,
                isSelected: false,
                accentOnSelect: false
            ) {
                if !viewModel.isImportingPlaylist {
                    withAnimation(.easeIn(duration: 0.15)) {
                        viewModel.showImportPlaylist = true
                    }
                }
            }
            .disabled(viewModel.isImportingPlaylist)
            .opacity(viewModel.isImportingPlaylist ? 0.6 : 1.0)
            .overlay(alignment: .trailing) {
                if viewModel.isImportingPlaylist {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.trailing, 16)
                }
            }
        }
    }

    // MARK: Status

    private var statusSection: some View {
        SidebarSection(title: "Status") {
            StatusRow(name: "yt-dlp", icon: "terminal",
                      isAvailable: YtDlp.isAvailable)
            StatusRow(name: "Last.fm", icon: "waveform",
                      isAvailable: AuthManager.shared.isAuthenticatedLastFm)
        }
    }

    private func playlistIcon(for playlist: Playlist) -> some View {
        let downloadedCount = playlist.tracks.filter { UserDataStore.shared.downloadedTracks[$0.id] != nil }.count
        
        let stateIndicator: AnyView
        if downloadedCount > 0 && downloadedCount == playlist.tracks.count {
            stateIndicator = AnyView(
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.success)
                    .background(Circle().fill(Color.black.opacity(0.8)))
            )
        } else if downloadedCount > 0 {
            stateIndicator = AnyView(
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.secondary)
                    .background(Circle().fill(Color.black.opacity(0.8)))
            )
        } else {
            stateIndicator = AnyView(EmptyView())
        }

        return AnyView(
            ZStack(alignment: .bottomTrailing) {
                if let url = playlist.tracks.first?.artworkURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        default:
                            PlaylistThumbnail(symbol: "music.note.list", tint: Theme.accent, size: 26)
                        }
                    }
                    .frame(width: 26, height: 26)
                    .clipShape(.rect(cornerRadius: 6))
                } else {
                    PlaylistThumbnail(symbol: "music.note.list", tint: Theme.accent, size: 26)
                }
                
                stateIndicator
                    .offset(x: 4, y: 4)
            }
        )
    }

    private var settingsRow: some View {
        SidebarRow(
            title: "Settings",
            systemIcon: "gearshape.fill",
            glyphSize: 16,
            isSelected: state.selection == .view(.settings),
            accentOnSelect: true
        ) {
            state.selection = .view(.settings)
            viewModel.selectedView = .settings
        }
    }

    private var navSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            let navViews: [MainView] = [.home, .search, .library, .lyrics, .queue, .likedSongs]
            ForEach(navViews) { view in
                SidebarRow(
                    title: view.title,
                    systemIcon: view.icon,
                    glyphSize: view == .likedSongs ? 14 : 16,
                    isSelected: state.selection == .view(view),
                    accentOnSelect: true
                ) {
                    state.selection = .view(view)
                    viewModel.selectedView = view
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    private var bottomSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let errorMessage = viewModel.errorMessage {
                ErrorPill(message: errorMessage)
            }
            if downloadManager.isDownloading, let status = downloadManager.currentStatus {
                DownloadPill(message: status, progress: downloadManager.currentProgress)
            }
            settingsRow
            userRow
        }
        .padding(10)
    }

    private var userRow: some View {
        let userName = NSFullUserName()
        let initial = userName.isEmpty ? "?" : String(userName.prefix(1)).uppercased()
        return HStack(spacing: 8) {
            UserAvatar(initial: initial)
            VStack(alignment: .leading, spacing: 1) {
                Text(userName.isEmpty ? "Account" : userName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                Text("Signed in")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }

    private func applySelection(_ new: SidebarSelection?) {
        switch new {
        case .view(let v):
            viewModel.selectedView = v
        case .playlist:
            viewModel.selectedView = .playlistDetail
        case .none:
            break
        }
    }
}

// MARK: - Sidebar Section

struct SidebarSection<Content: View, Trailing: View>: View {
    let title: String?
    let trailing: Trailing
    let content: Content

    init(title: String?, @ViewBuilder trailing: () -> Trailing = { EmptyView() }, @ViewBuilder content: () -> Content) {
        self.title = title
        self.trailing = trailing()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let title {
                HStack(alignment: .center) {
                    Text(title.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    trailing
                }
                .padding(.horizontal, 8)
                .padding(.top, 6)
                .padding(.bottom, 4)
            }
            content
        }
    }
}

class SidebarRowState: ObservableObject {
    @Published var isHovered = false
}

struct SidebarRow<Icon: View>: View {
    let title: String
    let icon: Icon
    let isSelected: Bool
    let accentOnSelect: Bool
    let action: () -> Void

    @StateObject private var state = SidebarRowState()

    init(
        title: String,
        systemIcon: String,
        glyphSize: CGFloat = 16,
        isSelected: Bool,
        accentOnSelect: Bool,
        action: @escaping () -> Void
    ) where Icon == AnyView {
        self.title = title
        self.icon = AnyView(
            Image(systemName: systemIcon)
                .font(.system(size: glyphSize, weight: .regular))
                .frame(width: 22, height: 22)
                .foregroundStyle(isSelected && accentOnSelect ? Theme.accent : .primary)
        )
        self.isSelected = isSelected
        self.accentOnSelect = accentOnSelect
        self.action = action
    }

    init(
        title: String,
        @ViewBuilder icon: @escaping () -> Icon,
        isSelected: Bool,
        accentOnSelect: Bool,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon()
        self.isSelected = isSelected
        self.accentOnSelect = accentOnSelect
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                AnyView(icon)
                    .frame(width: 26, height: 26)
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected && accentOnSelect ? Theme.accent : .primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect(cornerRadius: 6))
            .background {
                if isSelected {
                    if accentOnSelect {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Theme.accent.opacity(0.18))
                    } else {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(.primary.opacity(0.08))
                    }
                } else if state.isHovered {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.primary.opacity(0.05))
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            state.isHovered = hovering
        }
    }
}

// MARK: - Status Row

struct StatusRow: View {
    let name: String
    let icon: String
    let isAvailable: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(isAvailable ? .primary : .secondary)
                .frame(width: 22, height: 22)

            Text(name)
                .font(.system(size: 13))
                .foregroundStyle(isAvailable ? .primary : .secondary)

            Spacer()

            Circle()
                .fill(isAvailable ? Theme.success : Color.gray)
                .opacity(isAvailable ? 0.6 : 0.3)
                .frame(width: 6, height: 6)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

// MARK: - Error Pill

struct ErrorPill: View {
    let message: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.error)
            Text(message)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Theme.error.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Theme.error.opacity(0.35), lineWidth: 0.5)
        )
    }
}

// MARK: - Download Pill

struct DownloadPill: View {
    let message: String
    let progress: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if progress == nil || progress == 1.0 {
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(0.6)
                } else {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
                Text(message)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
            }
            if let progress = progress, progress < 1.0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.1))
                            .frame(height: 3)
                        Capsule().fill(Theme.accent)
                            .frame(width: geo.size.width * CGFloat(progress), height: 3)
                    }
                }
                .frame(height: 3)
                .padding(.horizontal, 2)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Theme.accent.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Theme.accent.opacity(0.3), lineWidth: 0.5)
        )
    }
}
