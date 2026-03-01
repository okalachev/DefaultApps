import Foundation
import CoreServices
import AppKit

/// Represents an application that can handle a URL scheme
struct AppHandler: Identifiable, Hashable {
    let id: String // bundle identifier
    let name: String
    let icon: NSImage
    let bundleURL: URL?
    
    static func == (lhs: AppHandler, rhs: AppHandler) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Represents a URI Scheme with its current default handler
struct URISchemeInfo: Identifiable, Hashable {
    let id: String // the scheme itself (e.g. "http", "tg")
    var scheme: String { id }
    var defaultHandler: String? // bundle identifier of default handler
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Manages interaction with macOS LaunchServices / NSWorkspace for URI schemes
class URISchemeManager {
    
    static let shared = URISchemeManager()
    
    // MARK: - Modern helpers
    
    /// Get all handler URLs for a URL scheme using NSWorkspace (modern, non-deprecated API)
    private func handlerURLs(for scheme: String) -> [URL] {
        guard let url = URL(string: "\(scheme)://") else { return [] }
        return NSWorkspace.shared.urlsForApplications(toOpen: url)
    }
    
    /// Get default handler URL for a URL scheme using NSWorkspace (modern API)
    private func defaultHandlerURL(for scheme: String) -> URL? {
        guard let url = URL(string: "\(scheme)://") else { return nil }
        return NSWorkspace.shared.urlForApplication(toOpen: url)
    }
    
    /// Known URL schemes to always check
    private let commonSchemes = [
        "http", "https", "ftp", "sftp", "ssh", "telnet",
        "mailto", "tel", "sms", "facetime", "facetime-audio",
        "vnc", "rdp", "afp", "smb", "nfs",
        "irc", "ircs", "xmpp", "sip", "sips",
        "itms", "macappstore", "macappstores",
        "maps", "calshow", "webcal",
        "message", "imessage",
        "tg", "telegram",
        "slack", "zoommtg", "zoomus",
        "spotify", "music",
        "vscode", "vscode-insiders",
        "x-apple-reminder",
        "photos", "photos-redirect",
        "shortcuts",
        "raycast",
        "obsidian",
        "notion",
        "figma",
        "discord",
        "skype",
        "whatsapp",
        "signal",
        "viber",
    ]
    
    /// Get all registered URI schemes that have at least one handler
    func getAllSchemes() -> [URISchemeInfo] {
        var schemes = Set<String>()
        
        // Check common schemes that have handlers
        for scheme in commonSchemes {
            if !handlerURLs(for: scheme).isEmpty {
                schemes.insert(scheme)
            }
        }
        
        // Also scan all installed apps for URL schemes they declare
        let additionalSchemes = discoverSchemesFromInstalledApps()
        for s in additionalSchemes {
            schemes.insert(s)
        }
        
        // Build URISchemeInfo array
        return schemes.sorted().map { scheme in
            let defaultURL = defaultHandlerURL(for: scheme)
            let defaultBundleID = defaultURL.flatMap { Bundle(url: $0)?.bundleIdentifier }
            return URISchemeInfo(id: scheme, defaultHandler: defaultBundleID)
        }
    }
    
    /// Discover URL schemes from apps installed on the system
    private func discoverSchemesFromInstalledApps() -> Set<String> {
        var schemes = Set<String>()
        
        let searchDirs = [
            "/Applications",
            "/System/Applications",
            NSHomeDirectory() + "/Applications",
            "/Applications/Utilities",
            "/System/Applications/Utilities"
        ]
        
        for dir in searchDirs {
            guard let enumerator = FileManager.default.enumerator(
                at: URL(fileURLWithPath: dir),
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            
            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension == "app" {
                    enumerator.skipDescendants()
                    if let bundle = Bundle(url: fileURL),
                       let urlTypes = bundle.infoDictionary?["CFBundleURLTypes"] as? [[String: Any]] {
                        for urlType in urlTypes {
                            if let urlSchemes = urlType["CFBundleURLSchemes"] as? [String] {
                                for scheme in urlSchemes {
                                    let lower = scheme.lowercased()
                                    // Filter out very internal schemes
                                    if !lower.hasPrefix("com.") && !lower.hasPrefix("dyn.") && !lower.isEmpty {
                                        schemes.insert(lower)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        return schemes
    }
    
    /// Get all handlers for a given URL scheme
    func getHandlers(for scheme: String) -> [AppHandler] {
        let appURLs = handlerURLs(for: scheme)
        
        var handlers: [AppHandler] = []
        var seenIDs = Set<String>()
        
        for appURL in appURLs {
            guard let bundle = Bundle(url: appURL),
                  let bundleID = bundle.bundleIdentifier else { continue }
            
            let lowerID = bundleID.lowercased()
            guard !seenIDs.contains(lowerID) else { continue }
            seenIDs.insert(lowerID)
            
            let name = FileManager.default.displayName(atPath: appURL.path)
                .replacingOccurrences(of: ".app", with: "")
            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            icon.size = NSSize(width: 32, height: 32)
            
            handlers.append(AppHandler(
                id: bundleID,
                name: name,
                icon: icon,
                bundleURL: appURL
            ))
        }
        
        return handlers.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    /// Get the default handler for a URL scheme
    func getDefaultHandler(for scheme: String) -> String? {
        guard let url = defaultHandlerURL(for: scheme),
              let bundle = Bundle(url: url) else { return nil }
        return bundle.bundleIdentifier
    }
    
    /// Set the default handler for a URL scheme
    @discardableResult
    func setDefaultHandler(for scheme: String, bundleID: String) -> Bool {
        let result = LSSetDefaultHandlerForURLScheme(scheme as CFString, bundleID as CFString)
        return result == noErr
    }
    
    /// Create an AppHandler from a bundle identifier
    func makeAppHandler(bundleID: String) -> AppHandler? {
        let workspace = NSWorkspace.shared
        guard let appURL = workspace.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        
        let name = FileManager.default.displayName(atPath: appURL.path)
            .replacingOccurrences(of: ".app", with: "")
        let icon = workspace.icon(forFile: appURL.path)
        icon.size = NSSize(width: 32, height: 32)
        
        return AppHandler(
            id: bundleID,
            name: name,
            icon: icon,
            bundleURL: appURL
        )
    }
}
