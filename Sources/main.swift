import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {

    private var pickerWindows: [NSWindow] = []
    private var pendingURLs: [URL] = []
    private var isReady = false
    private var hasReceivedURL = false
    private var escapeMonitor: Any?
    private var settingsWindow: NSWindow?

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Register the GetURL handler as early as possible. On a cold launch
        // triggered BY a link, macOS delivers the kAEGetURL Apple Event during
        // launch — before applicationDidFinishLaunching. Registering here (in
        // willFinishLaunching) ensures the very first URL isn't dropped, which
        // previously left the user staring at the About window instead of the
        // picker. The event still lands in pendingURLs (isReady is false until
        // didFinishLaunching), where it's drained once the UI is ready.
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURL(_:withReply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Install a single Escape key monitor
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.dismissFrontWindow()
                return nil
            }
            return event
        }

        isReady = true

        // Process any URLs that arrived before we were ready
        for url in pendingURLs {
            showPicker(for: url)
        }
        pendingURLs.removeAll()

        // If launched with no URL (e.g., user double-clicked the app),
        // show about window — but give URL events time to arrive first
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            if !self.hasReceivedURL && self.pickerWindows.isEmpty {
                self.showAboutWindow()
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showAboutWindow()
        }
        return true
    }

    @objc func handleGetURL(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue else { return }

        // URL(string:) silently fails on unencoded characters (spaces, certain
        // OAuth/SSO redirect payloads), which previously meant "no popup at all".
        // Fall back to percent-encoding before giving up.
        let url: URL
        if let parsed = URL(string: urlString) {
            url = parsed
        } else if let encoded = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let parsed = URL(string: encoded) {
            url = parsed
        } else {
            return
        }

        hasReceivedURL = true

        if isReady {
            showPicker(for: url)
        } else {
            pendingURLs.append(url)
        }
    }

    private func showPicker(for url: URL) {
        let browsers = BrowserDetector.shared.detectBrowsers()

        // Auto-open mode: launch the goto default immediately, unless the user
        // is holding Option (bypass) to deliberately reach the picker.
        let settings = SettingsStore.shared.settings
        if settings.autoOpenDefault, let defaultKey = settings.defaultKey {
            let bypassing = settings.bypassWithOption && NSEvent.modifierFlags.contains(.option)
            if !bypassing {
                let items = LaunchItemBuilder.flatten(browsers)
                if let item = items.first(where: { $0.key == defaultKey }) {
                    BrowserLauncher.open(url: url, browser: item.browser, profile: item.profile)
                    if pickerWindows.isEmpty {
                        NSApp.setActivationPolicy(.accessory)
                    }
                    return
                }
            }
        }

        let pickerView = PickerView(
            url: url,
            browsers: browsers,
            onDismiss: { [weak self] in self?.dismissFrontWindow() },
            onOpenSettings: { [weak self] in self?.showSettingsWindow() }
        )

        let hostingView = NSHostingView(rootView: pickerView)

        // Force layout so fittingSize is accurate
        hostingView.setFrameSize(NSSize(width: 380, height: 600))
        hostingView.layoutSubtreeIfNeeded()
        let fittingSize = hostingView.fittingSize
        let windowSize = NSSize(
            width: max(fittingSize.width, 380),
            height: max(fittingSize.height, 200)
        )
        hostingView.setFrameSize(windowSize)

        // Use a regular NSWindow (not NSPanel) for reliable activation
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.isMovableByWindowBackground = true
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isReleasedWhenClosed = false
        window.center()

        // Activate app and show window. orderFrontRegardless() is the reliable
        // path on recent macOS, where activate(ignoringOtherApps:) alone can
        // leave the window behind the frontmost app.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        // Handle window close via the X button
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] notification in
            guard let self = self, let closedWindow = notification.object as? NSWindow else { return }
            self.pickerWindows.removeAll { $0 === closedWindow }
            if self.pickerWindows.isEmpty {
                NSApp.setActivationPolicy(.accessory)
                NSApp.hide(nil)
            }
        }

        pickerWindows.append(window)
    }

    private func dismissFrontWindow() {
        guard let window = pickerWindows.last else { return }
        window.close()
    }

    func showSettingsWindow() {
        // Reuse an existing settings window if open.
        if let existing = settingsWindow {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            existing.makeKeyAndOrderFront(nil)
            existing.orderFrontRegardless()
            return
        }

        let browsers = BrowserDetector.shared.detectBrowsers()
        let settingsView = SettingsView(browsers: browsers)
        let hostingView = NSHostingView(rootView: settingsView)
        hostingView.setFrameSize(NSSize(width: 420, height: 520))
        hostingView.layoutSubtreeIfNeeded()

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: hostingView.frame.size),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.center()

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.settingsWindow = nil
            if self?.pickerWindows.isEmpty ?? true {
                NSApp.setActivationPolicy(.accessory)
            }
        }

        settingsWindow = window
    }

    private func showAboutWindow() {
        let aboutView = AboutView(onOpenSettings: { [weak self] in self?.showSettingsWindow() })
        let hostingView = NSHostingView(rootView: aboutView)
        hostingView.setFrameSize(NSSize(width: 320, height: 300))
        hostingView.layoutSubtreeIfNeeded()
        let fittingSize = hostingView.fittingSize
        hostingView.setFrameSize(NSSize(width: max(fittingSize.width, 320), height: max(fittingSize.height, 200)))

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: hostingView.frame.size),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.isMovableByWindowBackground = true
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.center()

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

struct AboutView: View {
    let onOpenSettings: () -> Void
    @State private var isDefaultBrowser = false

    var body: some View {
        VStack(spacing: 0) {
            appIcon
                .padding(.top, 4)
                .padding(.bottom, 14)

            Text("Browser Picker")
                .font(.system(size: 20, weight: .bold))
                .padding(.bottom, 5)

            Text("Every link you click asks which browser\nand profile to open it with.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 18)

            Divider()
                .padding(.bottom, 16)

            if isDefaultBrowser {
                Label("Set as your default browser", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.green)
                    .padding(.bottom, 14)
            } else {
                Button {
                    setAsDefaultBrowser()
                } label: {
                    Text("Make Default Browser")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.bottom, 6)

                Text("Opens System Settings › Desktop & Dock")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 14)
            }

            Button {
                onOpenSettings()
            } label: {
                Label("Settings…", systemImage: "gearshape")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Text("Version 1.1.1")
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.top, 16)
        }
        .padding(24)
        .frame(width: 320)
        .background(VisualEffectBackground())
        .onAppear {
            checkDefaultBrowser()
        }
    }

    /// In-app rendition of the app icon's "browser window + branching paths" motif.
    private var appIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.27, green: 0.56, blue: 1.0),
                                 Color(red: 0.10, green: 0.33, blue: 0.92)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: 72, height: 72)
                .shadow(color: .black.opacity(0.18), radius: 5, y: 2)

            VStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.white)
                    .frame(width: 34, height: 21)
                    .overlay(alignment: .topLeading) {
                        HStack(spacing: 2.5) {
                            ForEach(0..<3) { _ in
                                Circle()
                                    .fill(Color(red: 0.27, green: 0.56, blue: 1.0))
                                    .frame(width: 2.5, height: 2.5)
                            }
                        }
                        .padding(4)
                    }
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
    }

    private func checkDefaultBrowser() {
        if let defaultBrowser = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "https://example.com")!),
           let bundle = Bundle(url: defaultBrowser),
           bundle.bundleIdentifier == "com.nathanbrewer.BrowserPicker" {
            isDefaultBrowser = true
        }
    }

    private func setAsDefaultBrowser() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Desktop-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}

// --- Entry Point ---

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
