import SwiftUI

struct BrowserView: View {
    @State private var query: String = ""
    @State private var selectedTag: String? = nil
    @State private var toast: String? = nil
    @State private var showSettings = false
    @State private var isLoaded = false

    private let catalog = BufoCatalog.shared

    private var filtered: [Bufo] {
        catalog.search(query: query, tag: selectedTag)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoaded {
                    tagBar
                    Divider()
                    grid
                } else {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
            .navigationTitle("Bufos")
            .onAppear {
                if catalog.isLoaded {
                    isLoaded = true
                } else {
                    catalog.onLoaded { isLoaded = true }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search \(catalog.bufos.count) bufos")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Link("GitHub",
                         destination: URL(string: "https://github.com/edwardofclt/bufo-keyboard")!)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "info.circle")
                    }
                }
            }
            .sheet(isPresented: $showSettings) { AboutView() }
            .overlay(alignment: .bottom) { toastView }
        }
    }

    private var tagBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                tagChip(label: "All", isSelected: selectedTag == nil) { selectedTag = nil }
                ForEach(catalog.allTags, id: \.self) { tag in
                    tagChip(label: tag, isSelected: selectedTag == tag) {
                        selectedTag = (selectedTag == tag) ? nil : tag
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private func tagChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 12)], spacing: 12) {
                ForEach(filtered) { bufo in
                    Button { tap(bufo) } label: {
                        BufoImageView(bufo: bufo)
                            .frame(width: 64, height: 64)
                            .padding(6)
                            .background(Color.secondary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(bufo.displayName)
                }
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private var toastView: some View {
        if let toast {
            Text(toast)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color.black.opacity(0.85))
                .clipShape(Capsule())
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func tap(_ bufo: Bufo) {
        showToast("Copying...")
        BufoStickerService.copy(bufo) { result in
            if case .copied = result {
                RecentsStore.shared.record(bufo)
                showToast("Copied \(bufo.displayName) — paste anywhere")
            } else {
                showToast("Couldn't copy that bufo")
            }
        }
    }

    private func showToast(_ message: String) {
        withAnimation(.spring(duration: 0.25)) { toast = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeOut(duration: 0.25)) { toast = nil }
        }
    }
}

#Preview { BrowserView() }
