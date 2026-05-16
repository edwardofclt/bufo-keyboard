import SwiftUI
import UIKit

struct MessagesRootView: View {
    var onSelectBufo: (Bufo) -> Void
    var onRequestExpand: () -> Void
    var isExpanded: Bool = false

    /// Cap search results so the LazyVGrid doesn't allocate hundreds of cells
    /// for broad queries.
    private static let searchResultLimit = 200

    @State private var selectedTag: String? = nil
    @State private var isLoaded = false
    @State private var searchQuery: String = ""
    @FocusState private var searchFocused: Bool

    private let catalog = BufoCatalog.shared

    private var recents: [Bufo] {
        RecentsStore.shared.recents(from: catalog)
    }

    private var trimmedQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearching: Bool { !trimmedQuery.isEmpty }

    private var visibleBufos: [Bufo] {
        if isSearching {
            return Array(catalog.search(query: trimmedQuery).prefix(Self.searchResultLimit))
        }
        if selectedTag == "__recent" { return recents }
        if let tag = selectedTag {
            return catalog.bufos(forTag: tag)  // O(1) bucket lookup
        }
        return catalog.bufos
    }

    var body: some View {
        VStack(spacing: 0) {
            if isLoaded {
                searchBar
                if isExpanded && !isSearching {
                    tagsBar
                }
                if isExpanded {
                    Divider().opacity(0.4)
                }
                grid
            } else {
                loadingView
            }
        }
        .background(Color(uiColor: .systemBackground))
        .onAppear {
            if catalog.isLoaded {
                isLoaded = true
            } else {
                catalog.onLoaded { isLoaded = true }
            }
        }
        // Auto-expand the drawer the moment the user taps into the search field.
        // The system keyboard needs the expanded presentation style to be usable.
        .onChange(of: searchFocused) { focused in
            if focused && !isExpanded {
                onRequestExpand()
            }
        }
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
            Spacer()
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.callout)
                .foregroundStyle(.secondary)
            TextField("Search bufos", text: $searchQuery)
                .textFieldStyle(.plain)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .focused($searchFocused)
                .submitLabel(.search)
            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var tagsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                tagChip(label: "All", isSelected: selectedTag == nil) { selectedTag = nil }
                if !recents.isEmpty {
                    tagChip(label: "Recent", isSelected: selectedTag == "__recent",
                            systemImage: "clock") {
                        selectedTag = (selectedTag == "__recent") ? nil : "__recent"
                    }
                }
                ForEach(catalog.allTags, id: \.self) { tag in
                    tagChip(label: tag, isSelected: selectedTag == tag) {
                        selectedTag = (selectedTag == tag) ? nil : tag
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private func tagChip(label: String, isSelected: Bool, systemImage: String? = nil,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let systemImage { Image(systemName: systemImage).font(.caption2) }
                Text(label).font(.caption.weight(.medium))
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.18))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var grid: some View {
        ScrollView {
            if isSearching && visibleBufos.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("No bufos match \"\(trimmedQuery)\"")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 8)], spacing: 8) {
                    ForEach(visibleBufos) { bufo in
                        BufoMessageCell(bufo: bufo) {
                            onSelectBufo(bufo)
                        }
                    }
                }
                .padding(8)
            }
        }
        .overlay(alignment: .bottom) {
            if !isExpanded && !isSearching {
                expandButton
            }
        }
    }

    private var expandButton: some View {
        Button(action: onRequestExpand) {
            HStack {
                Image(systemName: "chevron.up")
                Text("Tap to expand")
                Image(systemName: "chevron.up")
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.accentColor.opacity(0.9))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.bottom, 8)
    }
}

private struct BufoMessageCell: View {
    let bufo: Bufo
    let onTap: () -> Void
    @State private var image: UIImage?

    var body: some View {
        Button(action: onTap) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Color.secondary.opacity(0.2)
                }
            }
            .frame(width: 56, height: 56)
            .padding(4)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(BufoCellButtonStyle())
        .accessibilityLabel(bufo.displayName)
        .task(id: bufo.id) {
            image = await ThumbnailCache.shared.thumbnail(for: bufo.fileURL)
        }
    }
}

private struct BufoCellButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
