import SwiftUI

struct KeyboardRootView: View {
    var hasFullAccess: Bool
    var onAdvance: () -> Void
    var onBackspace: () -> Void
    var onInsertText: (String) -> Void

    @State private var query: String = ""
    @State private var selectedTag: String? = nil
    @State private var toast: String? = nil

    private let catalog = BufoCatalog.shared

    private var filtered: [Bufo] {
        catalog.search(query: query, tag: selectedTag)
    }

    private var recents: [Bufo] {
        RecentsStore.shared.recents(from: catalog)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                searchAndTags
                Divider().opacity(0.4)
                if !hasFullAccess {
                    fullAccessBanner
                }
                grid
                Divider().opacity(0.4)
                bottomBar
            }
            .background(Color(uiColor: .systemBackground).opacity(0.001)) // hit-testing

            if let toast {
                toastView(toast)
                    .padding(.bottom, 56)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var searchAndTags: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search bufos", text: $query)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color.secondary.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 10))

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
            }
        }
        .padding(.horizontal, 8)
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
    }

    private var fullAccessBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Allow Full Access to send bufos").font(.caption.weight(.semibold))
                Text("Settings → General → Keyboard → Keyboards → Bufos → Allow Full Access")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(Color.orange.opacity(0.12))
    }

    private var visibleBufos: [Bufo] {
        if selectedTag == "__recent" { return recents }
        return filtered
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 56), spacing: 8)], spacing: 8) {
                ForEach(visibleBufos) { bufo in
                    BufoCell(bufo: bufo) { tap(bufo) }
                }
            }
            .padding(8)
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 8) {
            Button(action: onAdvance) {
                Image(systemName: "globe")
                    .font(.title3)
                    .frame(width: 44, height: 36)
                    .background(Color.secondary.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next keyboard")

            Spacer()

            Text("\(catalog.bufos.count) bufos")
                .font(.caption2).foregroundStyle(.secondary)

            Spacer()

            Button(action: onBackspace) {
                Image(systemName: "delete.left")
                    .font(.title3)
                    .frame(width: 44, height: 36)
                    .background(Color.secondary.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Backspace")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private func toastView(_ message: String) -> some View {
        Text(message)
            .font(.footnote.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Color.black.opacity(0.85))
            .clipShape(Capsule())
    }

    private func tap(_ bufo: Bufo) {
        guard hasFullAccess else {
            flashToast("Enable Full Access in Settings → Keyboards → Bufos")
            return
        }
        switch BufoStickerService.copy(bufo) {
        case .copied:
            RecentsStore.shared.record(bufo)
            flashToast("Copied — long-press the message field, then Paste")
        case .failed:
            flashToast("Couldn't copy that bufo")
        }
    }

    private func flashToast(_ message: String) {
        withAnimation(.spring(duration: 0.2)) { toast = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.25)) { toast = nil }
        }
    }
}

private struct BufoCell: View {
    let bufo: Bufo
    let onTap: () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: onTap) {
            BufoImageView(bufo: bufo)
                .frame(width: 48, height: 48)
                .padding(4)
                .background(Color.secondary.opacity(pressed ? 0.25 : 0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .scaleEffect(pressed ? 0.93 : 1)
                .animation(.easeOut(duration: 0.1), value: pressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
        .accessibilityLabel(bufo.displayName)
    }
}
