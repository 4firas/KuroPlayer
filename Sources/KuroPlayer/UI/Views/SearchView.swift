import SwiftUI

struct SearchView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ZStack(alignment: .top) {
            resultsContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            searchField
        }
        .onAppear {
            isSearchFocused = true
        }
    }

    // MARK: Search Field

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            TextField("Search tracks...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .focused($isSearchFocused)
                .onChange(of: viewModel.searchText) { _, newValue in
                    viewModel.searchTextChanged(newValue)
                }

            if !viewModel.searchText.isEmpty {
                Button(action: { viewModel.searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.35), radius: 12, y: -2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: Results

    @ViewBuilder
    private var resultsContent: some View {
        if viewModel.isSearching {
            VStack {
                ProgressView()
                Text("Searching...")
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
            ScrollView(showsIndicators: false) {
                Color.clear.frame(height: 70)

                LazyVStack(spacing: 1) {
                    ForEach(viewModel.searchResults) { track in
                        Button(action: {
                            viewModel.play(track: track)
                        }) {
                            TrackRowContent(track: track)
                        }
                        .buttonStyle(.plain)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
                        .contentShape(.rect(cornerRadius: 8))
                        .contextMenu {
                            TrackContextMenu(track: track, playlistId: nil, remainingQueue: [track])
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black, location: 0.05),
                        .init(color: .black, location: 0.95),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
}
