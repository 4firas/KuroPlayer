import SwiftUI

struct SearchView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Search tracks...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .onChange(of: viewModel.searchText) { _, newValue in
                        Task { await viewModel.search(query: newValue) }
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
            .glassEffect(.regular, in: .rect(cornerRadius: 12))
            .padding(24)
            
            // Results
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
                ScrollView {
                    GlassEffectContainer(spacing: 2) {
                        LazyVStack(spacing: 2) {
                            ForEach(viewModel.searchResults) { track in
                                Button(action: {
                                    viewModel.play(track: track)
                                }) {
                                    TrackRowContent(track: track)
                                }
                                .buttonStyle(.plain)
                                .glassEffect(
                                    .regular.interactive(),
                                    in: .rect(cornerRadius: 8)
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }
        }
    }
}
