import Foundation
import SwiftUI
import AppKit

@MainActor
class DefaultAppsViewModel: ObservableObject {
    @Published var schemes: [URISchemeInfo] = []
    @Published var selectedScheme: URISchemeInfo? = nil
    @Published var handlers: [AppHandler] = []
    @Published var currentDefault: String? = nil
    @Published var isLoading = true
    @Published var searchText = ""
    @Published var statusMessage: String? = nil
    
    private nonisolated let manager = URISchemeManager.shared
    
    var filteredSchemes: [URISchemeInfo] {
        if searchText.isEmpty {
            return schemes
        }
        let query = searchText
        return schemes.filter { scheme in
            if scheme.scheme.localizedCaseInsensitiveContains(query) {
                return true
            }
            // Also match by default handler app name
            if let handlerID = scheme.defaultHandler {
                let appName = readableAppName(handlerID)
                if appName.localizedCaseInsensitiveContains(query) {
                    return true
                }
                if handlerID.localizedCaseInsensitiveContains(query) {
                    return true
                }
            }
            return false
        }
    }
    
    private func readableAppName(_ bundleID: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return FileManager.default.displayName(atPath: url.path)
                .replacingOccurrences(of: ".app", with: "")
        }
        return bundleID
    }
    
    func loadSchemes() {
        isLoading = true
        Task {
            let result = await Task.detached {
                self.manager.getAllSchemes()
            }.value
            
            await MainActor.run {
                self.schemes = result
                self.isLoading = false
            }
        }
    }
    
    func selectScheme(_ scheme: URISchemeInfo) {
        selectedScheme = scheme
        loadHandlers(for: scheme.scheme)
    }
    
    func loadHandlers(for scheme: String) {
        Task {
            let result = await Task.detached {
                self.manager.getHandlers(for: scheme)
            }.value
            let defaultID = await Task.detached {
                self.manager.getDefaultHandler(for: scheme)
            }.value
            
            await MainActor.run {
                self.handlers = result
                self.currentDefault = defaultID
            }
        }
    }
    
    func setDefaultHandler(for scheme: String, bundleID: String) {
        let success = manager.setDefaultHandler(for: scheme, bundleID: bundleID)
        if success {
            currentDefault = bundleID
            statusMessage = "Default handler for \(scheme):// set to \(bundleID)"
            // Update the scheme info in the list
            if let idx = schemes.firstIndex(where: { $0.id == scheme }) {
                schemes[idx] = URISchemeInfo(id: scheme, defaultHandler: bundleID)
            }
        } else {
            statusMessage = "Failed to set default handler for \(scheme)://"
        }
        
        // Clear status after delay
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                if self.statusMessage?.contains(scheme) == true {
                    self.statusMessage = nil
                }
            }
        }
    }
    
    func selectCustomApp(for scheme: String) {
        let panel = NSOpenPanel()
        panel.title = "Choose Application"
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.treatsFilePackagesAsDirectories = false
        
        let response = panel.runModal()
        if response == .OK, let url = panel.url {
            if let bundle = Bundle(url: url),
               let bundleID = bundle.bundleIdentifier {
                setDefaultHandler(for: scheme, bundleID: bundleID)
                // Reload handlers to include the new one
                loadHandlers(for: scheme)
            }
        }
    }
    
    func refreshCurrentScheme() {
        if let scheme = selectedScheme {
            loadHandlers(for: scheme.scheme)
        }
    }
}
