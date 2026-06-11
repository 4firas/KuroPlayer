import SwiftUI

struct SearchView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Search")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(KurokulaTheme.foreground)
            }
            .padding(.horizontal)
            .padding(.top)
            
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(KurokulaTheme.gray)
                
                TextField("Search tracks...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .foregroundColor(KurokulaTheme.foreground)
                    .onChange(of: viewModel.searchText) { newValue in
                        Task { await viewModel.search(query: newValue) }
                    }
                
                if !viewModel.searchText.isEmpty {
                    Button(action: { viewModel.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(KurokulaTheme.gray)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(12)
            .background(KurokulaTheme.cardBackground)
            .cornerRadius(8)
            .padding(.horizontal)
            
            if viewModel.isSearching {
                VStack {
                    ProgressView()
                    Text("Searching...")
                        .foregroundColor(KurokulaTheme.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.searchText.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 60))
                        .foregroundColor(KurokulaTheme.gray)
                    
                    Text("Search across all your connected services")
                        .font(.title3)
                        .foregroundColor(KurokulaTheme.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.searchResults.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "music.note.slash")
                        .font(.system(size: 60))
                        .foregroundColor(KurokulaTheme.gray)
                    
                    Text("No results found")
                        .font(.title3)
                        .foregroundColor(KurokulaTheme.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(viewModel.searchResults) { track in
                            Button(action: {
                                viewModel.play(track: track)
                            }) {
                                TrackRowContent(track: track)
                            }
                            .buttonStyle(TrackRowButtonStyle(isActive: viewModel.currentTrack?.id == track.id))
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .background(KurokulaTheme.background)
    }
}
