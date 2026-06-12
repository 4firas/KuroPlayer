import SwiftUI

struct SearchView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search tracks, or paste a playlist link...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .onChange(of: viewModel.searchText) { _, newValue in
                        viewModel.searchTextChanged(newValue)
                    }
                    .onSubmit {
                        viewModel.searchNow()
                    }

                if !viewModel.searchText.isEmpty {
                    Button(action: { viewModel.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
            .padding(24)

            // Playlist link detected → offer import instead of searching
            if let playlistURL = viewModel.detectPlaylistURL(in: viewModel.searchText) {
                PlaylistImportCard(url: playlistURL)
                    .padding(.horizontal, 24)
                Spacer()
            } else if viewModel.isSearching {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Searching YouTube Music & SoundCloud…")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.searchText.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)

                    Text("Search across all your connected services")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    Text("Tip: paste a SoundCloud set or YouTube playlist link to import it")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.searchResults.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "music.note.slash")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)

                    Text("No results found")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    GlassEffectContainer(spacing: 2) {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(viewModel.searchResults.enumerated()), id: \.element.id) { index, track in
                                Button(action: {
                                    viewModel.playFromList(viewModel.searchResults, startingAt: index)
                                }) {
                                    TrackRowContent(track: track)
                                }
                                .buttonStyle(.plain)
                                .glassEffect(
                                    .regular.interactive(),
                                    in: .rect(cornerRadius: 8)
                                )
                                .contextMenu {
                                    Button("Add to Queue") {
                                        viewModel.addToQueue(track)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
    }
}

/// Shown when the search field contains an importable playlist link.
struct PlaylistImportCard: View {
    let url: URL

    @EnvironmentObject var viewModel: PlayerViewModel
    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "square.and.arrow.down")
                .font(.title2)
                .foregroundStyle(theme.accent)

            VStack(alignment: .leading, spacing: 4) {
                Text("Playlist link detected")
                    .font(.headline)
                Text(viewModel.importStatusMessage ?? url.absoluteString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if viewModel.isImportingPlaylist {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button("Import Playlist") {
                    viewModel.importPlaylist(from: url.absoluteString)
                }
                .buttonStyle(.glassProminent)
            }
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }
}
