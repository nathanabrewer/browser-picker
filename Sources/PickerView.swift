import SwiftUI
import AppKit

struct PickerView: View {
    let url: URL
    let browsers: [Browser]
    let onDismiss: () -> Void
    let onOpenSettings: () -> Void

    @State private var hoveredKey: String? = nil
    @State private var searchText: String = ""

    /// Flattened + ordered launch items, default pinned to the very top.
    private var items: [LaunchItem] {
        let flat = LaunchItemBuilder.flatten(browsers)
        var ordered = LaunchItemBuilder.ordered(flat, order: SettingsStore.shared.settings.order)
        if let defaultKey = SettingsStore.shared.settings.defaultKey,
           let idx = ordered.firstIndex(where: { $0.key == defaultKey }) {
            let item = ordered.remove(at: idx)
            ordered.insert(item, at: 0)
        }
        return ordered
    }

    private var defaultKey: String? { SettingsStore.shared.settings.defaultKey }

    private var filteredItems: [LaunchItem] {
        let all = items
        if searchText.isEmpty { return all }
        return all.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }

    private var defaultItem: LaunchItem? {
        guard let key = defaultKey else { return nil }
        return items.first { $0.key == key }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with URL
            VStack(spacing: 8) {
                Text("Open With")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 6) {
                    Image(systemName: "link")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text(url.absoluteString)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .padding(.top, 18)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            // Search field
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12, weight: .medium))
                TextField("Filter browsers…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            Divider()

            // Flat list of launch items
            ScrollView {
                if filteredItems.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 22))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("No browsers match “\(searchText)”")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 36)
                }
                LazyVStack(spacing: 2) {
                    ForEach(filteredItems) { item in
                        LaunchRow(
                            item: item,
                            isDefault: item.key == defaultKey,
                            hoveredKey: $hoveredKey,
                            onSelect: {
                                BrowserLauncher.open(url: url, browser: item.browser, profile: item.profile)
                                onDismiss()
                            }
                        )
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
            }
            .frame(maxHeight: 400)

            Divider()

            // Footer
            HStack(spacing: 8) {
                Button("Cancel") {
                    onDismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .help("Dismiss without opening (Esc)")

                Button {
                    onOpenSettings()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .help("Reorder browsers & set your default")

                Spacer()

                // Return-to-launch the default item.
                if let defaultItem = defaultItem {
                    Button("Open \(defaultItem.displayName)") {
                        BrowserLauncher.open(url: url, browser: defaultItem.browser, profile: defaultItem.profile)
                        onDismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .font(.system(size: 11))
                    .keyboardShortcut(.defaultAction)
                    .lineLimit(1)
                } else {
                    Text("Browser Picker")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 380)
        .background(VisualEffectBackground())
    }
}

struct LaunchRow: View {
    let item: LaunchItem
    let isDefault: Bool
    @Binding var hoveredKey: String?
    let onSelect: () -> Void

    private var isHovered: Bool { hoveredKey == item.key }

    var body: some View {
        HStack(spacing: 11) {
            if let icon = item.browser.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 28, height: 28)
            } else {
                Image(systemName: "globe")
                    .font(.system(size: 22))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(item.browser.name)
                    .font(.system(size: 13, weight: .medium))
                if let profile = item.profile {
                    Text(profile.name)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            Spacer(minLength: 6)

            if isDefault {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.accentColor)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .opacity(isHovered ? 0.7 : 0.0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered
                    ? Color.accentColor.opacity(0.14)
                    : (isDefault ? Color.accentColor.opacity(0.06) : Color.clear))
        )
        .contentShape(Rectangle())
        .onHover { hovered in
            withAnimation(.easeOut(duration: 0.12)) {
                hoveredKey = hovered ? item.key : (hoveredKey == item.key ? nil : hoveredKey)
            }
        }
        .onTapGesture {
            onSelect()
        }
    }
}

// MARK: - Settings window

struct SettingsView: View {
    let browsers: [Browser]

    @State private var items: [LaunchItem]
    @State private var defaultKey: String?
    @State private var autoOpenDefault: Bool
    @State private var bypassWithOption: Bool

    init(browsers: [Browser]) {
        self.browsers = browsers
        let flat = LaunchItemBuilder.flatten(browsers)
        let ordered = LaunchItemBuilder.ordered(flat, order: SettingsStore.shared.settings.order)
        _items = State(initialValue: ordered)
        _defaultKey = State(initialValue: SettingsStore.shared.settings.defaultKey)
        _autoOpenDefault = State(initialValue: SettingsStore.shared.settings.autoOpenDefault)
        _bypassWithOption = State(initialValue: SettingsStore.shared.settings.bypassWithOption)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Browser Picker Settings")
                .font(.system(size: 16, weight: .semibold))
                .padding(.top, 16)
                .padding(.horizontal, 16)

            Text("Drag to reorder. Click the star to set your goto default.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 2)
                .padding(.bottom, 10)

            List {
                ForEach(items) { item in
                    HStack(spacing: 10) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.5))

                        if let icon = item.browser.icon {
                            Image(nsImage: icon).resizable().frame(width: 22, height: 22)
                        } else {
                            Image(systemName: "globe").frame(width: 22, height: 22)
                        }

                        VStack(alignment: .leading, spacing: 0) {
                            Text(item.browser.name).font(.system(size: 12, weight: .medium))
                            if let profile = item.profile {
                                Text(profile.name).font(.system(size: 10)).foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        Button {
                            defaultKey = (defaultKey == item.key) ? nil : item.key
                            persist()
                        } label: {
                            Image(systemName: defaultKey == item.key ? "star.fill" : "star")
                                .foregroundColor(defaultKey == item.key ? .accentColor : .secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Set as default")
                    }
                    .padding(.vertical, 2)
                }
                .onMove { indices, newOffset in
                    items.move(fromOffsets: indices, toOffset: newOffset)
                    persist()
                }
            }
            .listStyle(.inset)
            .frame(minHeight: 220)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: $autoOpenDefault) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Skip the picker — always use my default")
                            .font(.system(size: 12))
                        Text("Opens your starred default instantly, without showing this window.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .disabled(defaultKey == nil)
                .onChange(of: autoOpenDefault) { _ in persist() }

                if autoOpenDefault {
                    Toggle(isOn: $bypassWithOption) {
                        Text("Hold ⌥ Option while clicking a link to still show the picker")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .toggleStyle(.checkbox)
                    .onChange(of: bypassWithOption) { _ in persist() }
                    .padding(.leading, 4)
                }

                if defaultKey == nil {
                    Text("Set a default (★) above to enable auto-open.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
        }
        .frame(width: 420)
        .background(VisualEffectBackground())
    }

    private func persist() {
        SettingsStore.shared.update { s in
            s.order = items.map { $0.key }
            s.defaultKey = defaultKey
            s.autoOpenDefault = autoOpenDefault
            s.bypassWithOption = bypassWithOption
        }
    }
}

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
