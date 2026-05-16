import SwiftUI
import UIKit

/// Colors tuned to blend with the surrounding iOS system keyboard chrome
/// (the tray that shows globe/dictation buttons below custom keyboards).
enum KeyboardTheme {
    /// Background of the keyboard chrome — matches the iOS system tray below
    /// custom keyboards (the strip showing globe/dictation buttons).
    static let chromeBackground = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)
            : UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1)
    })

    /// Top color of an individual key (white-ish in light, mid-gray in dark).
    static let keyTopBackground = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.42, green: 0.42, blue: 0.44, alpha: 1)
            : UIColor.white
    })
}

struct KeyboardRootView: View {
    var hasFullAccess: Bool
    var isLoaded: Bool = false
    /// Called by the inner content whenever the user opens or closes the
    /// in-keyboard search QWERTY. The view controller uses this to grow the
    /// keyboard's height constraint so the bufo grid stays visible.
    var onSearchActiveChanged: ((Bool) -> Void)? = nil
    /// Apple requires every third-party keyboard to provide a way to switch
    /// back to the previous keyboard. The view controller wires this to
    /// `advanceToNextInputMode()`.
    var onAdvanceInputMode: (() -> Void)? = nil

    @State private var toast: String? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            if isLoaded {
                // Separate view struct - only instantiated when isLoaded is true
                KeyboardLoadedContent(
                    hasFullAccess: hasFullAccess,
                    toast: $toast,
                    onSearchActiveChanged: onSearchActiveChanged,
                    onAdvanceInputMode: onAdvanceInputMode
                )
                .transition(.opacity.animation(.easeIn(duration: 0.15)))
            } else {
                loadingView
            }

            if let toast {
                toastView(toast)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading bufos...")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            Spacer()
        }
    }

    private func toastView(_ message: String) -> some View {
        Text(message)
            .font(.footnote.weight(.medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.secondary.opacity(0.25), lineWidth: 0.5))
    }
}

// Separate struct - SwiftUI won't instantiate this until isLoaded is true.
// Implements chunked loading: only the currently selected tag's bufos are
// rendered (typically <100), instead of all 1,200+ in the catalog.
private struct KeyboardLoadedContent: View {
    let hasFullAccess: Bool
    @Binding var toast: String?
    let onSearchActiveChanged: ((Bool) -> Void)?
    let onAdvanceInputMode: (() -> Void)?

    /// Page size for the "All" view to keep LazyVGrid instantiation fast.
    private static let allViewPageSize = 150

    /// Cap search results to avoid huge LazyVGrid allocations on broad queries.
    private static let searchResultLimit = 200

    @State private var selectedTag: String
    @State private var allViewLimit: Int = allViewPageSize
    @State private var searchQuery: String = ""
    /// When true, the mini QWERTY is visible. Independent of searchQuery so the
    /// user can dismiss the keyboard without clearing their query (or vice versa).
    @State private var searchActive: Bool = false

    private let catalog = BufoCatalog.shared

    init(hasFullAccess: Bool, toast: Binding<String?>,
         onSearchActiveChanged: ((Bool) -> Void)?,
         onAdvanceInputMode: (() -> Void)?) {
        self.hasFullAccess = hasFullAccess
        self._toast = toast
        self.onSearchActiveChanged = onSearchActiveChanged
        self.onAdvanceInputMode = onAdvanceInputMode
        // Default to Recent tab if user has any recents, otherwise first
        // category alphabetically. Avoids rendering all 1,200+ bufos at launch.
        let catalog = BufoCatalog.shared
        let hasRecents = !RecentsStore.shared.recents(from: catalog).isEmpty
        if hasRecents {
            self._selectedTag = State(initialValue: "__recent")
        } else if let firstTag = catalog.allTags.first {
            self._selectedTag = State(initialValue: firstTag)
        } else {
            self._selectedTag = State(initialValue: "__all")
        }
    }

    private var recents: [Bufo] {
        RecentsStore.shared.recents(from: catalog)
    }

    private var trimmedQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearching: Bool { !trimmedQuery.isEmpty }

    private var visibleBufos: [Bufo] {
        if isSearching {
            // Free-text search across the entire catalog. Capped to keep
            // LazyVGrid instantiation fast.
            let results = catalog.search(query: trimmedQuery)
            return Array(results.prefix(Self.searchResultLimit))
        }
        switch selectedTag {
        case "__recent": return recents
        case "__all":
            return Array(catalog.bufos.prefix(allViewLimit))
        default:
            return catalog.bufos(forTag: selectedTag)
        }
    }

    private var hasMoreInAllView: Bool {
        !isSearching && selectedTag == "__all" && allViewLimit < catalog.bufos.count
    }

    var body: some View {
        Group {
            if !hasFullAccess {
                fullAccessRequired
            } else {
                browser
            }
        }
        .animation(.easeOut(duration: 0.18), value: searchActive)
        .onChange(of: searchActive) { newValue in
            onSearchActiveChanged?(newValue)
        }
    }

    private var browser: some View {
        VStack(spacing: 0) {
            searchBar
            if !searchActive && !isSearching {
                tagsBar
            }
            Divider().opacity(0.4)
            grid
            if searchActive {
                MiniQWERTY(
                    onKey: { ch in searchQuery.append(ch) },
                    onBackspace: {
                        if !searchQuery.isEmpty { searchQuery.removeLast() }
                    },
                    onSpace: { searchQuery.append(" ") },
                    onClose: {
                        searchActive = false
                        searchQuery = ""
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            globeButton
            Button {
                searchActive = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if searchQuery.isEmpty {
                        Text("Search bufos")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(searchQuery)
                            .font(.callout)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
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
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.secondary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    /// Apple-required button that switches to the user's next installed
    /// keyboard. Hit area is enlarged with `.contentShape` so the tappable
    /// region meets the 44pt accessibility minimum even though the icon is small.
    private var globeButton: some View {
        Button {
            onAdvanceInputMode?()
        } label: {
            Image(systemName: "globe")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Next keyboard")
    }

    private var tagsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if !recents.isEmpty {
                    tagChip(label: "Recent", isSelected: selectedTag == "__recent",
                            systemImage: "clock") {
                        selectTag("__recent")
                    }
                }
                tagChip(label: "All", isSelected: selectedTag == "__all") {
                    selectTag("__all")
                }
                ForEach(catalog.allTags, id: \.self) { tag in
                    tagChip(label: tag, isSelected: selectedTag == tag) {
                        selectTag(tag)
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(.vertical, 6)
    }

    private func selectTag(_ tag: String) {
        selectedTag = tag
        allViewLimit = Self.allViewPageSize  // Reset pagination when switching tabs
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

    /// Full-keyboard blocker shown when the user hasn't granted Full Access.
    /// Sending bufos via the pasteboard requires Full Access, so the keyboard
    /// is unusable without it.
    private var fullAccessRequired: some View {
        VStack(spacing: 14) {
            HStack {
                globeButton
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
            VStack(spacing: 6) {
                Text("Full Access Required")
                    .font(.headline)
                Text("Bufo Keyboard needs Full Access to copy stickers to the pasteboard.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            VStack(alignment: .leading, spacing: 4) {
                step(number: "1", text: "Open Settings")
                step(number: "2", text: "Tap General → Keyboards → Keyboards")
                step(number: "3", text: "Tap Bufo Stickers")
                step(number: "4", text: "Enable Allow Full Access")
            }
            .font(.footnote)
            .padding(.horizontal, 24)
            Spacer(minLength: 0)
            Text("Your clipboard data stays on-device.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func step(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Color.accentColor)
                .clipShape(Circle())
            Text(text)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
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
                .padding(.top, 18)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 56), spacing: 8)], spacing: 8) {
                    ForEach(visibleBufos) { bufo in
                        BufoCell(bufo: bufo) { tap(bufo) }
                    }
                }
                .padding(8)
            }

            if hasMoreInAllView {
                Button {
                    allViewLimit += Self.allViewPageSize
                } label: {
                    Text("Load more (\(catalog.bufos.count - allViewLimit) remaining)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color.accentColor.opacity(0.9))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.bottom, 12)
            }
        }
    }

    private func tap(_ bufo: Bufo) {
        guard hasFullAccess else {
            flashToast("Enable Full Access in Settings → Keyboards → Bufos")
            return
        }
        // iOS may suppress haptics in keyboard extensions depending on the
        // system "Haptic Keyboard" setting; that's expected — the call is
        // a no-op when disallowed.
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        flashToast("Copying...")
        BufoStickerService.copy(bufo) { result in
            switch result {
            case .copied:
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                RecentsStore.shared.record(bufo)
                flashToast("Copied — long-press to Paste")
            case .failed:
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                flashToast("Couldn't copy that bufo")
            }
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

    var body: some View {
        Button(action: onTap) {
            BufoImageView(bufo: bufo)
                .frame(width: 48, height: 48)
                .padding(4)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(BufoCellButtonStyle())
        .accessibilityLabel(bufo.displayName)
    }
}

private struct BufoCellButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Mini QWERTY
//
// SwiftUI TextField cannot receive input inside a UIInputViewController because
// the keyboard extension itself IS the keyboard. We render our own letter
// buttons that append directly to the search query state.
private struct MiniQWERTY: View {
    let onKey: (Character) -> Void
    let onBackspace: () -> Void
    let onSpace: () -> Void
    let onClose: () -> Void

    private static let row1: [Character] = Array("qwertyuiop")
    private static let row2: [Character] = Array("asdfghjkl")
    private static let row3: [Character] = Array("zxcvbnm")

    private static let keyHeight: CGFloat = 34
    private static let keySpacing: CGFloat = 4
    private static let outerPad: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            // Widest row is 10 keys → divide width into 10 equal units.
            let unit = (geo.size.width - Self.outerPad * 2 - Self.keySpacing * 9) / 10
            let h = Self.keyHeight

            VStack(spacing: 6) {
                // Row 1: q w e r t y u i o p
                HStack(spacing: Self.keySpacing) {
                    ForEach(Self.row1, id: \.self) { ch in
                        LetterKey(character: ch) { onKey(ch) }
                            .frame(width: unit, height: h)
                    }
                }
                // Row 2: a s d f g h j k l (9 keys, half-unit indent each side)
                HStack(spacing: Self.keySpacing) {
                    Color.clear.frame(width: unit * 0.5, height: h)
                    ForEach(Self.row2, id: \.self) { ch in
                        LetterKey(character: ch) { onKey(ch) }
                            .frame(width: unit, height: h)
                    }
                    Color.clear.frame(width: unit * 0.5, height: h)
                }
                // Row 3: ✕(close) | z x c v b n m | ⌫
                HStack(spacing: Self.keySpacing) {
                    IconKey(systemImage: "xmark", action: onClose,
                            accessibilityLabel: "Close search")
                        .frame(width: unit * 1.4, height: h)
                    ForEach(Self.row3, id: \.self) { ch in
                        LetterKey(character: ch) { onKey(ch) }
                            .frame(width: unit, height: h)
                    }
                    IconKey(systemImage: "delete.left", action: onBackspace,
                            accessibilityLabel: "Backspace")
                        .frame(width: unit * 1.4, height: h)
                }
                // Row 4: full-width space bar
                SpaceKey(action: onSpace)
                    .frame(width: unit * 10 + Self.keySpacing * 9, height: h)
            }
            .padding(.horizontal, Self.outerPad)
            .padding(.vertical, 6)
            .frame(width: geo.size.width, alignment: .center)
        }
        .frame(height: Self.keyHeight * 4 + 6 * 3 + 12)
    }
}

private struct LetterKey: View {
    let character: Character
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(String(character))
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(KeyboardTheme.keyTopBackground)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .shadow(color: .black.opacity(0.12), radius: 0, x: 0, y: 1)
        }
        .buttonStyle(KeyButtonStyle())
        .accessibilityLabel(String(character))
    }
}

private struct IconKey: View {
    let systemImage: String
    let action: () -> Void
    let accessibilityLabel: String

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.secondary.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(KeyButtonStyle())
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct SpaceKey: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("space")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(KeyboardTheme.keyTopBackground)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .shadow(color: .black.opacity(0.12), radius: 0, x: 0, y: 1)
        }
        .buttonStyle(KeyButtonStyle())
        .accessibilityLabel("Space")
    }
}

private struct KeyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}
