//
//  BoardSearchToolbar.swift
//  Pinboard
//

import SwiftUI

struct BoardSearchToolbar<NormalContent: View>: View {
    @Bindable private var search: BoardSearchController
    let onSelectResult: (BoardSearchResult) -> Void
    private let normalContent: NormalContent

    @FocusState private var isSearchFieldFocused: Bool
    @Namespace private var glassNamespace
    @State private var mainToolbarSize = CGSize(width: 420, height: 46)

    init(
        search: BoardSearchController,
        onSelectResult: @escaping (BoardSearchResult) -> Void,
        @ViewBuilder normalContent: () -> NormalContent
    ) {
        _search = Bindable(search)
        self.onSelectResult = onSelectResult
        self.normalContent = normalContent()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            glassControls

            if shouldShowSuggestionPanel {
                suggestionPanel
                    .frame(width: searchFieldWidth)
                    .transition(
                        .scale(scale: 0.96, anchor: .topLeading)
                            .combined(with: .opacity)
                    )
            }
        }
        .onChange(of: search.isPresented) { _, isPresented in
            if isPresented {
                Task { @MainActor in
                    isSearchFieldFocused = true
                }
            } else {
                isSearchFieldFocused = false
            }
        }
        .onExitCommand {
            guard search.isPresented else { return }
            closeSearch()
        }
        .animation(.snappy(duration: 0.38), value: search.isPresented)
        .animation(.easeOut(duration: 0.14), value: search.results)
        .animation(.easeOut(duration: 0.14), value: search.recentQueries)
    }

    @ViewBuilder
    private var glassControls: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 14) {
                controlContent
            }
        } else {
            controlContent
        }
    }

    @ViewBuilder
    private var controlContent: some View {
        if search.isPresented {
            HStack(spacing: controlSpacing) {
                capsuleSurface(
                    searchField,
                    id: "mainToolbar",
                    interactive: true
                )

                capsuleSurface(
                    closeButton,
                    id: "searchButton",
                    interactive: true
                )
            }
        } else {
            HStack(spacing: controlSpacing) {
                capsuleSurface(
                    measuredNormalContent,
                    id: "mainToolbar",
                    interactive: false
                )

                capsuleSurface(
                    searchButton,
                    id: "searchButton",
                    interactive: true
                )
            }
        }
    }

    private var measuredNormalContent: some View {
        normalContent
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: MainToolbarSizePreferenceKey.self,
                        value: geometry.size
                    )
                }
            }
            .onPreferenceChange(MainToolbarSizePreferenceKey.self) { size in
                guard size.width > 0, size.height > 0 else { return }
                mainToolbarSize = size
            }
    }

    private var searchButton: some View {
        Button {
            withAnimation(.snappy(duration: 0.38)) {
                search.open()
            }
        } label: {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .matchedGeometryEffect(id: "searchGlyph", in: glassNamespace)
                .frame(width: toolbarHeight, height: toolbarHeight)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary.opacity(0.78))
        .accessibilityLabel("Search notes")
        .help("Search notes (⌘F)")
        .keyboardShortcut("f", modifiers: .command)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PinboardTheme.selection)
                .matchedGeometryEffect(id: "searchGlyph", in: glassNamespace)

            TextField("Search titles and notes", text: $search.query)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .focused($isSearchFieldFocused)
                .onSubmit(submitSearch)

            if search.isSearching {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: PinboardTheme.Controls.toolbarButtonSize)
            }

        }
        .padding(.horizontal, 12)
        .frame(width: searchFieldWidth, height: toolbarHeight)
    }

    private var closeButton: some View {
        Button(action: closeSearch) {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .semibold))
                .frame(width: toolbarHeight, height: toolbarHeight)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary.opacity(0.70))
        .accessibilityLabel("Close search")
        .help("Close search")
    }

    @ViewBuilder
    private var suggestionPanel: some View {
        let content = ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if search.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    panelHeader("Recent Searches")

                    ForEach(search.recentQueries.prefix(10), id: \.self) { query in
                        SearchSuggestionRow(
                            systemImage: "clock.arrow.circlepath",
                            title: query,
                            subtitle: nil
                        ) {
                            search.useRecentQuery(query)
                            isSearchFieldFocused = true
                        }
                    }
                } else if !search.results.isEmpty {
                    panelHeader("Suggestions")

                    ForEach(search.results) { result in
                        SearchSuggestionRow(
                            kind: CardKind(rawValue: result.kindRawValue) ?? .text,
                            title: result.title,
                            subtitle: result.snippet
                        ) {
                            select(result)
                        }
                    }
                } else if !search.isSearching, search.hasResolvedFilter {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.tertiary)
                        Text("No matching notes")
                            .foregroundStyle(.secondary)
                    }
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
            }
            .padding(.vertical, 6)
        }
        .scrollIndicators(.automatic)
        .frame(height: suggestionPanelHeight)

        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
        } else {
            content
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                }
        }
    }

    private func panelHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, 14)
            .padding(.top, 4)
            .padding(.bottom, 5)
    }

    @ViewBuilder
    private func capsuleSurface<Content: View>(
        _ content: Content,
        id: String,
        interactive: Bool
    ) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(
                    interactive ? .regular.interactive() : .regular,
                    in: .capsule
                )
                .glassEffectID(id, in: glassNamespace)
                .glassEffectTransition(.matchedGeometry)
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.28), radius: 20, y: 10)
        }
    }

    private var shouldShowSuggestionPanel: Bool {
        guard search.isPresented else { return false }
        if search.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return !search.recentQueries.isEmpty
        }
        return !search.results.isEmpty || (!search.isSearching && search.hasResolvedFilter)
    }

    private var suggestionPanelHeight: CGFloat {
        let trimmedQuery = search.query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedQuery.isEmpty {
            return min(CGFloat(search.recentQueries.prefix(10).count) * 32 + 36, 360)
        }
        if !search.results.isEmpty {
            return min(CGFloat(search.results.count) * 40 + 36, 360)
        }
        return 48
    }

    private var searchFieldWidth: CGFloat {
        max(360, mainToolbarSize.width)
    }

    private var toolbarHeight: CGFloat {
        max(38, mainToolbarSize.height)
    }

    private let controlSpacing: CGFloat = 10

    private func submitSearch() {
        if let result = search.results.first {
            select(result)
        } else {
            search.recordCurrentQuery()
        }
    }

    private func select(_ result: BoardSearchResult) {
        search.recordCurrentQuery()
        onSelectResult(result)
    }

    private func closeSearch() {
        withAnimation(.snappy(duration: 0.38)) {
            search.close()
        }
    }
}

private struct SearchSuggestionRow: View {
    let kind: CardKind?
    let systemImage: String?
    let title: String
    let subtitle: String?
    let action: () -> Void

    @State private var isHovering = false

    init(
        kind: CardKind,
        title: String,
        subtitle: String?,
        action: @escaping () -> Void
    ) {
        self.kind = kind
        systemImage = nil
        self.title = title
        self.subtitle = subtitle
        self.action = action
    }

    init(
        systemImage: String,
        title: String,
        subtitle: String?,
        action: @escaping () -> Void
    ) {
        kind = nil
        self.systemImage = systemImage
        self.title = title
        self.subtitle = subtitle
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                if let kind {
                    CardKindIcon(
                        kind: kind,
                        size: 18,
                        backgroundColor: .primary.opacity(0.08),
                        foregroundColor: .primary.opacity(0.80),
                        borderColor: .primary.opacity(0.14)
                    )
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title.isEmpty ? "Untitled" : title)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 6)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, subtitle == nil ? 7 : 6)
            .contentShape(Rectangle())
            .background(
                isHovering ? Color.primary.opacity(0.08) : Color.clear,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.10), value: isHovering)
    }
}

private struct MainToolbarSizePreferenceKey: PreferenceKey {
    static let defaultValue = CGSize.zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}
