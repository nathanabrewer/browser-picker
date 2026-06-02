import Foundation
import AppKit

// MARK: - Stable identity for a launch target

/// A single, flattened launch choice: a browser, optionally with a specific profile.
/// This is what the user sees as one row in the picker and in Settings.
struct LaunchItem: Identifiable, Hashable {
    let browser: Browser
    let profile: BrowserProfile?

    /// Stable key that survives relaunches (unlike the random UUIDs on Browser/BrowserProfile).
    var key: String {
        if let profile = profile {
            return "\(browser.bundleIdentifier)#\(profile.profileDirectory)"
        }
        return browser.bundleIdentifier
    }

    var id: String { key }

    var displayName: String {
        if let profile = profile {
            return "\(browser.name) — \(profile.name)"
        }
        return browser.name
    }

    static func == (lhs: LaunchItem, rhs: LaunchItem) -> Bool { lhs.key == rhs.key }
    func hash(into hasher: inout Hasher) { hasher.combine(key) }
}

// MARK: - Persisted settings

struct Settings: Codable {
    /// Ordered item keys. Items not present here are appended in detection order.
    var order: [String] = []
    /// The "goto" item key, if any.
    var defaultKey: String? = nil
    /// When true and a default is set, open it immediately without showing the picker.
    var autoOpenDefault: Bool = false
    /// When auto-opening, holding this modifier at click time forces the picker to show.
    /// (Option key — robust and rarely pressed accidentally.)
    var bypassWithOption: Bool = true
}

final class SettingsStore {
    static let shared = SettingsStore()

    private let defaultsKey = "BrowserPickerSettings"
    private(set) var settings: Settings

    private init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode(Settings.self, from: data) {
            settings = decoded
        } else {
            settings = Settings()
        }
    }

    func update(_ mutate: (inout Settings) -> Void) {
        mutate(&settings)
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}

// MARK: - Flattening + ordering

enum LaunchItemBuilder {
    /// Flatten detected browsers into one item per profile (or one item per profile-less browser).
    static func flatten(_ browsers: [Browser]) -> [LaunchItem] {
        var items: [LaunchItem] = []
        for browser in browsers {
            if browser.profiles.isEmpty {
                items.append(LaunchItem(browser: browser, profile: nil))
            } else {
                for profile in browser.profiles {
                    items.append(LaunchItem(browser: browser, profile: profile))
                }
            }
        }
        return items
    }

    /// Apply the user's saved order. Known items sort by their saved index;
    /// newly discovered items keep their detection order and land at the end.
    static func ordered(_ items: [LaunchItem], order: [String]) -> [LaunchItem] {
        let indexByKey: [String: Int] = Dictionary(
            uniqueKeysWithValues: order.enumerated().map { ($1, $0) }
        )
        return items.enumerated().sorted { a, b in
            let ia = indexByKey[a.element.key] ?? (order.count + a.offset)
            let ib = indexByKey[b.element.key] ?? (order.count + b.offset)
            return ia < ib
        }.map { $0.element }
    }
}
