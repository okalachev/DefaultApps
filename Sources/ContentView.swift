import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var viewModel = DefaultAppsViewModel()
    
    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
        } detail: {
            DetailView(viewModel: viewModel)
        }
        .frame(minWidth: 750, minHeight: 500)
        .onAppear {
            viewModel.loadSchemes()
        }
        .overlay(alignment: .bottom) {
            if let msg = viewModel.statusMessage {
                StatusBar(message: msg)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.statusMessage)
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @ObservedObject var viewModel: DefaultAppsViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                ProgressView("Scanning URI schemes…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.filteredSchemes, selection: Binding<URISchemeInfo.ID?>(
                    get: { viewModel.selectedScheme?.id },
                    set: { id in
                        if let id, let scheme = viewModel.schemes.first(where: { $0.id == id }) {
                            viewModel.selectScheme(scheme)
                        }
                    }
                )) { scheme in
                    SchemeRowView(scheme: scheme)
                        .tag(scheme.id)
                }
                .listStyle(.sidebar)
                .searchable(text: $viewModel.searchText, placement: .sidebar, prompt: "Filter schemes…")
            }
        }
        .safeAreaInset(edge: .top) {
            HStack {
                Text("URI Schemes")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.filteredSchemes.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.secondary.opacity(0.2)))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.bar)
        }
        .frame(minWidth: 220, idealWidth: 260)
    }
}

// MARK: - Scheme Row

struct SchemeRowView: View {
    let scheme: URISchemeInfo
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "link")
                .foregroundColor(.accentColor)
                .font(.system(size: 14))
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(scheme.scheme)://")
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                
                if let handler = scheme.defaultHandler {
                    Text(readableAppName(handler))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 3)
    }
    
    private func readableAppName(_ bundleID: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return FileManager.default.displayName(atPath: url.path)
                .replacingOccurrences(of: ".app", with: "")
        }
        return bundleID
    }
}

// MARK: - Detail View

struct DetailView: View {
    @ObservedObject var viewModel: DefaultAppsViewModel
    
    var body: some View {
        if let scheme = viewModel.selectedScheme {
            VStack(spacing: 0) {
                // Header
                SchemeHeaderView(scheme: scheme, viewModel: viewModel)
                
                Divider()
                
                // Handler list
                if viewModel.handlers.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "app.dashed")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No registered handlers")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(viewModel.handlers) { handler in
                                HandlerRowView(
                                    handler: handler,
                                    isDefault: handler.id.lowercased() == viewModel.currentDefault?.lowercased(),
                                    scheme: scheme.scheme,
                                    viewModel: viewModel
                                )
                            }
                        }
                        .padding(16)
                    }
                }
                
                Divider()
                
                // Bottom toolbar
                BottomToolbar(scheme: scheme, viewModel: viewModel)
            }
        } else {
            VStack(spacing: 16) {
                Image(systemName: "arrow.left.circle")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary.opacity(0.5))
                Text("Select a URI scheme from the sidebar")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Scheme Header

struct SchemeHeaderView: View {
    let scheme: URISchemeInfo
    @ObservedObject var viewModel: DefaultAppsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.accentColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(scheme.scheme)://")
                        .font(.system(.title2, design: .monospaced))
                        .fontWeight(.bold)
                    
                    if let defaultID = viewModel.currentDefault,
                       let handler = viewModel.handlers.first(where: { $0.id.lowercased() == defaultID.lowercased() }) {
                        HStack(spacing: 4) {
                            Text("Default:")
                                .foregroundColor(.secondary)
                            Image(nsImage: handler.icon)
                                .resizable()
                                .frame(width: 16, height: 16)
                            Text(handler.name)
                                .fontWeight(.medium)
                        }
                        .font(.subheadline)
                    } else if let defaultID = viewModel.currentDefault {
                        HStack(spacing: 4) {
                            Text("Default:")
                                .foregroundColor(.secondary)
                            Text(defaultID)
                        }
                        .font(.subheadline)
                    } else {
                        Text("No default handler")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button {
                    viewModel.refreshCurrentScheme()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh handlers")
            }
        }
        .padding(16)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Handler Row

struct HandlerRowView: View {
    let handler: AppHandler
    let isDefault: Bool
    let scheme: String
    @ObservedObject var viewModel: DefaultAppsViewModel
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: handler.icon)
                .resizable()
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(handler.name)
                    .font(.system(size: 14, weight: .medium))
                Text(handler.id)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isDefault {
                Label("Default", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.green.opacity(0.15)))
            } else {
                Button("Set as Default") {
                    viewModel.setDefaultHandler(for: scheme, bundleID: handler.id)
                }
                .buttonStyle(.bordered)
                .opacity(isHovered ? 1.0 : 0.7)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isDefault ? Color.accentColor.opacity(0.06) : (isHovered ? Color(nsColor: .controlBackgroundColor) : Color.clear))
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Bottom Toolbar

struct BottomToolbar: View {
    let scheme: URISchemeInfo
    @ObservedObject var viewModel: DefaultAppsViewModel
    
    var body: some View {
        HStack {
            Button {
                viewModel.selectCustomApp(for: scheme.scheme)
            } label: {
                Label("Choose Application…", systemImage: "folder.badge.plus")
            }
            
            Spacer()
            
            Text("\(viewModel.handlers.count) handler(s) available")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Status Bar

struct StatusBar: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.accentColor))
            .padding(.bottom, 8)
            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
    }
}
