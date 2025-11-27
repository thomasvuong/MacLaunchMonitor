import Foundation
import SwiftUI
import AppKit
import Combine

final class MonitorController: ObservableObject {

    struct MonitoredItem: Identifiable, Codable, Equatable {
        var id: UUID = UUID()
        var label: String            // the launchd label (com.xxx.yyy)
        var displayName: String     // user-chosen friendly name
        var dateAdded: Date = Date() // track when the service was added
    }

    // config path
    let configURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".launchd_monitor/config.json")

    @Published var monitored: [MonitoredItem] = []
    @Published var statuses: [String: String] = [:] // label -> "RUNNING"/"STOPPED"/"NOT LOADED"
    @Published var expandedLabel: String? = nil

    private var timer: AnyCancellable?

    init() {
        loadConfig()
    }

    // MARK: - Config
    func loadConfig() {
        do {
            let data = try Data(contentsOf: configURL)
            let decoded = try JSONDecoder().decode([MonitoredItem].self, from: data)
            DispatchQueue.main.async {
                self.monitored = decoded
            }
        } catch {
            // no config yet, start empty
            DispatchQueue.main.async {
                self.monitored = []
            }
        }
    }

    func saveConfig() {
        do {
            let dir = configURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(monitored)
            try data.write(to: configURL, options: .atomic)
        } catch {
            NSLog("Failed writing config: \(error)")
        }
    }

    // MARK: - Scanning services
    /// Returns all launchctl labels on the system (user and system)
    func scanAllLabels(completion: @escaping ([String]) -> Void) {
        // Parse launchctl list output manually to avoid shell issues
        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.shell("launchctl list")
            let lines = result.split(separator: "\n")
                .dropFirst() // skip header line
                .map { line -> String? in
                    // Each line is: PID Status Label
                    // We want the 3rd column (Label)
                    let parts = line.split(separator: "\t", omittingEmptySubsequences: true)
                    if parts.count >= 3 {
                        return String(parts[2])
                    }
                    // Sometimes separated by spaces
                    let spaceParts = line.split(separator: " ", omittingEmptySubsequences: true)
                    if spaceParts.count >= 3 {
                        return String(spaceParts[2])
                    }
                    return nil
                }
                .compactMap { $0 }
                .filter { !$0.isEmpty && $0 != "-" }
            DispatchQueue.main.async {
                completion(lines)
            }
        }
    }

    // MARK: - Status checking
    func refreshStatuses() {
        let labels = monitored.map { $0.label }
        DispatchQueue.global(qos: .userInitiated).async {
            var newStatuses: [String: String] = [:]
            for label in labels {
                // Use launchctl print to see if the job exists
                let cmd = "launchctl print gui/$(id -u) \(label) &>/dev/null && echo RUNNING || (launchctl list | grep -q \"\(label)\" && echo RUNNING || echo STOPPED)"
                let out = self.shell(cmd).trimmingCharacters(in: .whitespacesAndNewlines)
                newStatuses[label] = out.isEmpty ? "STOPPED" : out
            }
            DispatchQueue.main.async {
                self.statuses = newStatuses
            }
        }
    }

    // MARK: - Actions: Start / Stop / Restart
    func start(label: String, completion: ((Bool)->Void)? = nil) {
        guard let plistPath = findPlistPathSync(for: label) else {
            // attempt to bootstrap using assumed path in ~/Library/LaunchAgents/<label>.plist
            let fallback = "~/Library/LaunchAgents/\(label).plist"
            let cmd = "if [ -f \(fallback) ]; then launchctl bootstrap gui/$(id -u) \(fallback); fi"
            let _ = shell(cmd)
            DispatchQueue.main.async {
                self.refreshStatuses()
                completion?(true)
            }
            return
        }
        let cmd = "launchctl bootstrap gui/$(id -u) \(plistPath) 2>/dev/null || launchctl load \(plistPath) 2>/dev/null"
        _ = shell(cmd)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.refreshStatuses()
            completion?(true)
        }
    }

    func stop(label: String, completion: ((Bool)->Void)? = nil) {
        // if we have path, use bootout on path; else use label
        if let plistPath = findPlistPathSync(for: label) {
            let cmd = "launchctl bootout gui/$(id -u) \(plistPath) 2>/dev/null || launchctl unload \(plistPath) 2>/dev/null || launchctl bootout gui/$(id -u) \(label) 2>/dev/null"
            _ = shell(cmd)
        } else {
            let cmd = "launchctl bootout gui/$(id -u) \(label) 2>/dev/null || launchctl unload \(label) 2>/dev/null"
            _ = shell(cmd)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.refreshStatuses()
            completion?(true)
        }
    }

    func restart(label: String, completion: ((Bool)->Void)? = nil) {
        stop(label: label) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                self.start(label: label) { ok in
                    completion?(ok)
                }
            }
        }
    }

    // MARK: - Helpers & Plist viewing
    /// Find plist path quickly by searching common directories
    func findPlistPathSync(for label: String) -> String? {
        // search common directories
        let paths = [
            "\(NSHomeDirectory())/Library/LaunchAgents",
            "/Library/LaunchAgents",
            "/Library/LaunchDaemons",
            "/System/Library/LaunchAgents",
            "/System/Library/LaunchDaemons"
        ]
        for base in paths {
            let cmd = "grep -R --include='*.plist' -l \"<string>\\s*\(label)\\s*</string>\" \(base) 2>/dev/null | head -n 1"
            let out = shell(cmd).trimmingCharacters(in: .whitespacesAndNewlines)
            if !out.isEmpty {
                return out
            }
            // also try filename matching label
            let fileGuess = "\(base)/\(label).plist"
            if FileManager.default.fileExists(atPath: fileGuess) {
                return fileGuess
            }
        }
        return nil
    }

    func readPlistContents(for label: String) -> String {
        if let path = findPlistPathSync(for: label) {
            // pretty print
            let cmd = "plutil -p \(quoted(path)) 2>/dev/null || cat \(quoted(path))"
            return shell(cmd)
        } else {
            return "Plist not found in common locations for label \(label)."
        }
    }

    func revealPlistInFinder(for label: String) {
        if let path = findPlistPathSync(for: label) {
            DispatchQueue.main.async {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
            }
        }
    }

    // MARK: - Auto refresh
    func startAutoRefresh() {
        timer = Timer.publish(every: 5.0, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            self?.refreshStatuses()
        }
    }
    func stopAutoRefresh() {
        timer?.cancel()
        timer = nil
    }

    // MARK: - Window management
    func setupFloatingWindow() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let window = NSApplication.shared.windows.first {
                window.titlebarAppearsTransparent = true
                window.isOpaque = false
                window.backgroundColor = .clear
                window.level = .floating
                window.styleMask.insert(.fullSizeContentView)
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                // position on right edge center
                if let screen = NSScreen.main {
                    let frame = screen.visibleFrame
                    let w = CGFloat(90)
                    let h = min(frame.height * 0.6, 700)
                    let x = frame.origin.x + frame.size.width - w - 12
                    let y = frame.origin.y + (frame.size.height - h)/2
                    window.setFrame(NSRect(x: x, y: y, width: w, height: h), display: true)
                }
                window.isMovableByWindowBackground = true
            }
        }
    }

    // MARK: - Add / Remove monitored items
    func addMonitored(label: String, displayName: String) {
        let item = MonitoredItem(label: label, displayName: displayName)
        monitored.append(item)
        saveConfig()
        refreshStatuses()
    }
    func removeMonitored(id: UUID) {
        monitored.removeAll { $0.id == id }
        saveConfig()
    }
    func updateDisplayName(id: UUID, newName: String) {
        if let idx = monitored.firstIndex(where: { $0.id == id }) {
            monitored[idx].displayName = newName
            saveConfig()
        }
    }

    // MARK: - Shell utility
    private func shell(_ command: String) -> String {
        // use /bin/bash -c (non-login shell to avoid /etc/profile permission issues)
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", command]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return "ERROR: \(error)"
        }
    }

    private func quoted(_ s: String) -> String {
        return s.replacingOccurrences(of: " ", with: "\\ ")
    }
}
