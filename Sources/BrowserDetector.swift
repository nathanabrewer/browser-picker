import Foundation
import AppKit

struct BrowserProfile: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let profileDirectory: String  // e.g. "Default", "Profile 1"
}

struct Browser: Identifiable {
    let id = UUID()
    let name: String
    let bundleIdentifier: String
    let path: String
    let icon: NSImage?
    let profiles: [BrowserProfile]
    let isChromiumBased: Bool
}

class BrowserDetector {

    static let shared = BrowserDetector()

    // Known Chromium browsers and their Application Support paths
    private let chromiumBrowsers: [(bundleId: String, appSupportPath: String)] = [
        ("com.google.Chrome", "Google/Chrome"),
        ("com.google.Chrome.canary", "Google/Chrome Canary"),
        ("com.brave.Browser", "BraveSoftware/Brave-Browser"),
        ("com.microsoft.edgemac", "Microsoft Edge"),
        ("com.vivaldi.Vivaldi", "Vivaldi"),
        ("company.thebrowser.Browser", "Arc/User Data"),
        ("com.operasoftware.Opera", "com.operasoftware.Opera"),
    ]

    func detectBrowsers() -> [Browser] {
        var browsers: [Browser] = []

        // Find all apps that can handle https URLs
        let httpsURL = URL(string: "https://example.com")!
        let allBrowserBundles = NSWorkspace.shared.urlsForApplications(toOpen: httpsURL)

        for appURL in allBrowserBundles {
            guard let bundle = Bundle(url: appURL),
                  let bundleId = bundle.bundleIdentifier else { continue }

            // Skip ourselves
            if bundleId == "com.nathanbrewer.BrowserPicker" { continue }

            let appName = FileManager.default.displayName(atPath: appURL.path)
            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            icon.size = NSSize(width: 32, height: 32)

            // Check if this is a Chromium browser we know about
            let chromiumInfo = chromiumBrowsers.first { $0.bundleId == bundleId }
            var profiles: [BrowserProfile] = []

            if let chromiumInfo = chromiumInfo {
                profiles = detectChromiumProfiles(appSupportSubpath: chromiumInfo.appSupportPath)
            } else if bundleId == "org.mozilla.firefox" {
                profiles = detectFirefoxProfiles()
            }

            browsers.append(Browser(
                name: appName,
                bundleIdentifier: bundleId,
                path: appURL.path,
                icon: icon,
                profiles: profiles,
                isChromiumBased: chromiumInfo != nil
            ))
        }

        // Sort: browsers with profiles first, then alphabetically
        browsers.sort { a, b in
            if !a.profiles.isEmpty && b.profiles.isEmpty { return true }
            if a.profiles.isEmpty && !b.profiles.isEmpty { return false }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }

        return browsers
    }

    private func detectChromiumProfiles(appSupportSubpath: String) -> [BrowserProfile] {
        let appSupport = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support")
            .appendingPathComponent(appSupportSubpath)

        let localStatePath = appSupport.appendingPathComponent("Local State")

        guard let data = try? Data(contentsOf: localStatePath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profileSection = json["profile"] as? [String: Any],
              let infoCache = profileSection["info_cache"] as? [String: Any] else {
            return []
        }

        var profiles: [BrowserProfile] = []
        for (dirName, info) in infoCache {
            guard let profileInfo = info as? [String: Any] else { continue }
            let displayName = profileInfo["name"] as? String
                ?? profileInfo["gaia_name"] as? String
                ?? dirName
            profiles.append(BrowserProfile(name: displayName, profileDirectory: dirName))
        }

        profiles.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return profiles
    }

    private func detectFirefoxProfiles() -> [BrowserProfile] {
        let profilesIni = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Firefox/profiles.ini")

        guard let content = try? String(contentsOf: profilesIni, encoding: .utf8) else {
            return []
        }

        var profiles: [BrowserProfile] = []
        var currentName: String?
        var currentPath: String?

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[Profile") {
                if let name = currentName, let path = currentPath {
                    profiles.append(BrowserProfile(name: name, profileDirectory: path))
                }
                currentName = nil
                currentPath = nil
            } else if trimmed.hasPrefix("Name=") {
                currentName = String(trimmed.dropFirst(5))
            } else if trimmed.hasPrefix("Path=") {
                currentPath = String(trimmed.dropFirst(5))
            }
        }
        if let name = currentName, let path = currentPath {
            profiles.append(BrowserProfile(name: name, profileDirectory: path))
        }

        return profiles
    }
}

class BrowserLauncher {

    static func open(url: URL, browser: Browser, profile: BrowserProfile?) {
        if browser.isChromiumBased, let profile = profile {
            // Launch Chromium-based browser with specific profile
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            task.arguments = [
                "-na", browser.path,
                "--args",
                "--profile-directory=\(profile.profileDirectory)",
                url.absoluteString
            ]
            try? task.run()
        } else if browser.bundleIdentifier == "org.mozilla.firefox", let profile = profile {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            task.arguments = [
                "-na", browser.path,
                "--args",
                "-P", profile.name,
                url.absoluteString
            ]
            try? task.run()
        } else {
            // Generic: just open with the browser app
            NSWorkspace.shared.open(
                [url],
                withApplicationAt: URL(fileURLWithPath: browser.path),
                configuration: NSWorkspace.OpenConfiguration()
            )
        }
    }
}
