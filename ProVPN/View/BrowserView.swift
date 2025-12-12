//
//  BrowserView.swift
//  ProVPN
//
//  Created by DREAMWORLD on 11/12/25.
//

import SwiftUI
import WebKit

/// Wrapper for WKWebView to use in SwiftUI
struct WebView: UIViewRepresentable {
    @Binding var urlString: String
    @Binding var isLoading: Bool
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var currentURL: String?
    @Binding var pageTitle: String?
    
    let webView: WKWebView
    var shouldLoadURL: Bool = false
    var coordinatorStore: WebViewStore?
    
    func makeUIView(context: Context) -> WKWebView {
        // Set delegates
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        
        // Configure web view
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = true
        
        // Store reference in coordinator (use the passed webView directly)
        context.coordinator.setWebView(webView)
        
        // Store coordinator in store if available
        coordinatorStore?.coordinator = context.coordinator
        
        // Update initial state
        DispatchQueue.main.async {
            context.coordinator.updateNavigationState()
        }
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Only load URL if explicitly requested and it's different from current URL
        if shouldLoadURL && !urlString.isEmpty {
            let currentURLString = uiView.url?.absoluteString ?? ""
            // Only load if it's a different URL
            if urlString != currentURLString {
                context.coordinator.loadURL(urlString)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: WebView
        weak var webView: WKWebView?
        private var lastLoadedURL: String?
        private var isLoadingURL: Bool = false // Track if we're currently loading a URL
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func setWebView(_ webView: WKWebView) {
            self.webView = webView
        }
        
        func loadURL(_ urlString: String, force: Bool = false) {
            guard let webView = webView else { return }
            
            // Prevent multiple simultaneous loads (unless forced)
            if isLoadingURL && !force {
                return
            }
            
            // Normalize the URL for comparison
            var urlToLoad = urlString
            
            // Add https:// if no scheme is provided
            if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
                if urlString.contains(".") && !urlString.contains(" ") {
                    urlToLoad = "https://\(urlString)"
                } else {
                    // Treat as search query
                    let encodedQuery = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? urlString
                    urlToLoad = "https://www.google.com/search?q=\(encodedQuery)"
                }
            }
            
            // Don't reload if it's the same URL (compare normalized URLs) - unless forced
            if !force {
                let currentURLString = webView.url?.absoluteString ?? ""
                if urlToLoad == currentURLString {
                    return
                }
                
                // Don't reload if we just loaded this URL
                if lastLoadedURL == urlToLoad {
                    return
                }
            }
            
            guard let url = URL(string: urlToLoad) else { return }
            
            // Mark as loading
            isLoadingURL = true
            
            // Stop any current loading
            if webView.isLoading {
                webView.stopLoading()
            }
            
            lastLoadedURL = urlToLoad
            let request = URLRequest(url: url)
            webView.load(request)
        }
        
        func goBack() {
            guard let webView = webView, webView.canGoBack else { return }
            webView.goBack()
            // Update state immediately
            updateNavigationState()
        }
        
        func goForward() {
            guard let webView = webView, webView.canGoForward else { return }
            webView.goForward()
            // Update state immediately
            updateNavigationState()
        }
        
        func reload() {
            webView?.reload()
        }
        
        func stopLoading() {
            webView?.stopLoading()
        }
        
        func updateNavigationState() {
            guard let webView = webView else { return }
            DispatchQueue.main.async {
                self.parent.canGoBack = webView.canGoBack
                self.parent.canGoForward = webView.canGoForward
                self.parent.currentURL = webView.url?.absoluteString
                self.parent.pageTitle = webView.title ?? "Browser"
            }
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
                self.isLoadingURL = false // Reset flag when navigation actually starts
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.updateNavigationState()
                
                // Update last loaded URL
                if let url = webView.url?.absoluteString {
                    self.lastLoadedURL = url
                }
            }
        }
        
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            // Update state when navigation commits (before finish)
            DispatchQueue.main.async {
                self.updateNavigationState()
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                
                // Ignore cancellation errors (-999)
                let nsError = error as NSError
                if nsError.code != NSURLErrorCancelled {
                    print("Navigation failed: \(error.localizedDescription)")
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                
                // Ignore cancellation errors (-999)
                let nsError = error as NSError
                if nsError.code != NSURLErrorCancelled {
                    print("Provisional navigation failed: \(error.localizedDescription)")
                }
            }
        }
        
        // Handle new window requests
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
    }
}

/// Main Browser View with controls
struct BrowserView: View {
    @ObservedObject var viewModel: ServerListViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    @State private var urlString: String = ""
    @State private var isLoading: Bool = false
    @State private var canGoBack: Bool = false
    @State private var canGoForward: Bool = false
    @State private var currentURL: String?
    @State private var pageTitle: String?
    @State private var showBookmarks: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var shareURL: URL?
    @State private var shouldLoadURL: Bool = false
    @FocusState private var isAddressBarFocused: Bool
    
    // Create WebView once and reuse it
    @StateObject private var webViewStore = WebViewStore()
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // VPN Status Bar
            if viewModel.isConnected() {
                VPNStatusBanner(viewModel: viewModel, isIPad: isIPad)
            }
            
            // Address Bar
            AddressBarView(
                urlString: $urlString,
                isLoading: isLoading,
                isAddressBarFocused: $isAddressBarFocused,
                onGo: {
                    loadURL()
                },
                onRefresh: {
                    webViewStore.coordinator?.reload()
                },
                onStop: {
                    webViewStore.coordinator?.stopLoading()
                },
                isIPad: isIPad
            )
            
            // Web View
            WebView(
                urlString: $urlString,
                isLoading: $isLoading,
                canGoBack: $canGoBack,
                canGoForward: $canGoForward,
                currentURL: $currentURL,
                pageTitle: $pageTitle,
                webView: webViewStore.webView,
                shouldLoadURL: shouldLoadURL,
                coordinatorStore: webViewStore
            )
            .onAppear {
                // Load default page if no URL is set
                if urlString.isEmpty {
                    urlString = "https://www.google.com"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        shouldLoadURL = true
                    }
                }
            }
            .onChange(of: currentURL) { newURL in
                // Update address bar when URL changes from navigation (but not when user is typing)
                // Only update if it's different and user is not actively editing
                if let newURL = newURL, !isAddressBarFocused {
                    // Only update if significantly different (avoid minor changes)
                    if newURL != urlString && !newURL.isEmpty {
                        urlString = newURL
                    }
                }
            }
            
            // Toolbar
            BrowserToolbar(
                canGoBack: canGoBack,
                canGoForward: canGoForward,
                onBack: {
                    // Use the webView directly from store
                    if webViewStore.webView.canGoBack {
                        webViewStore.webView.goBack()
                    }
                },
                onForward: {
                    // Use the webView directly from store
                    if webViewStore.webView.canGoForward {
                        webViewStore.webView.goForward()
                    }
                },
                onShare: {
                    if let url = currentURL, let shareURL = URL(string: url) {
                        self.shareURL = shareURL
                        showShareSheet = true
                    }
                },
                onBookmarks: {
                    showBookmarks = true
                },
                onHome: {
                    // Force load home page
                    let homeURL = "https://www.google.com"
                    urlString = homeURL
                    // Directly load through coordinator to bypass checks
                    webViewStore.coordinator?.loadURL(homeURL, force: true)
                },
                isIPad: isIPad
            )
        }
        .navigationTitle(pageTitle ?? "Browser")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .foregroundColor(.cyan)
            }
        }
        .sheet(isPresented: $showBookmarks) {
            BookmarksView(
                onSelectBookmark: { url in
                    urlString = url
                    loadURL()
                    showBookmarks = false
                },
                isIPad: isIPad
            )
        }
        .sheet(isPresented: $showShareSheet) {
            if let shareURL = shareURL {
                ShareSheet(activityItems: [shareURL])
            }
        }
    }
    
    private func loadURL() {
        isAddressBarFocused = false
        
        // Set flag to trigger load, then immediately reset it
        // This ensures updateUIView only processes it once
        shouldLoadURL = true
        
        // Reset flag immediately after SwiftUI processes the update
        DispatchQueue.main.async {
            self.shouldLoadURL = false
        }
    }
}

// MARK: - WebView Store
class WebViewStore: ObservableObject {
    let webView: WKWebView
    var coordinator: WebView.Coordinator?
    
    init() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        self.webView = WKWebView(frame: .zero, configuration: config)
    }
}

// MARK: - VPN Status Banner
struct VPNStatusBanner: View {
    @ObservedObject var viewModel: ServerListViewModel
    let isIPad: Bool
    
    var body: some View {
        HStack(spacing: isIPad ? 12 : 8) {
            Image(systemName: "lock.shield.fill")
                .foregroundColor(.green)
                .font(isIPad ? .body : .caption)
            
            if let server = viewModel.selectedServer {
                Text("Protected by \(server.name) Server")
                    .font(isIPad ? .subheadline : .caption)
                    .foregroundColor(.primary)
            } else {
                Text("VPN Active")
                    .font(isIPad ? .subheadline : .caption)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            Circle()
                .fill(Color.green)
                .frame(width: isIPad ? 10 : 8, height: isIPad ? 10 : 8)
        }
        .padding(.horizontal, isIPad ? 16 : 12)
        .padding(.vertical, isIPad ? 10 : 8)
        .background(Color.green.opacity(0.15))
    }
}

// MARK: - Address Bar
struct AddressBarView: View {
    @Binding var urlString: String
    let isLoading: Bool
    @FocusState.Binding var isAddressBarFocused: Bool
    let onGo: () -> Void
    let onRefresh: () -> Void
    let onStop: () -> Void
    let isIPad: Bool
    
    var body: some View {
        HStack(spacing: isIPad ? 12 : 8) {
            HStack(spacing: isIPad ? 10 : 8) {
                Image(systemName: "lock.fill")
                    .foregroundColor(.secondary)
                    .font(isIPad ? .caption : .caption2)
                
                TextField("Search or enter website", text: $urlString)
                    .font(isIPad ? .body : .subheadline)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .keyboardType(.webSearch)
                    .submitLabel(.go)
                    .focused($isAddressBarFocused)
                    .onSubmit {
                        onGo()
                    }
                
                if !urlString.isEmpty {
                    Button(action: {
                        urlString = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(isIPad ? .caption : .caption2)
                    }
                }
            }
            .padding(.horizontal, isIPad ? 12 : 10)
            .padding(.vertical, isIPad ? 10 : 8)
            .background(Color(UIColor.systemGray6))
            .cornerRadius(isIPad ? 12 : 10)
            
            // Refresh/Stop Button
            Button(action: {
                if isLoading {
                    onStop()
                } else {
                    onRefresh()
                }
            }) {
                Image(systemName: isLoading ? "xmark" : "arrow.clockwise")
                    .foregroundColor(.cyan)
                    .font(isIPad ? .body : .subheadline)
                    .frame(width: isIPad ? 40 : 36, height: isIPad ? 40 : 36)
            }
        }
        .padding(.horizontal, isIPad ? 16 : 12)
        .padding(.vertical, isIPad ? 12 : 10)
        .background(Color(UIColor.systemBackground))
    }
}

// MARK: - Browser Toolbar
struct BrowserToolbar: View {
    let canGoBack: Bool
    let canGoForward: Bool
    let onBack: () -> Void
    let onForward: () -> Void
    let onShare: () -> Void
    let onBookmarks: () -> Void
    let onHome: () -> Void
    let isIPad: Bool
    
    var body: some View {
        HStack(spacing: isIPad ? 30 : 20) {
            // Back Button
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(isIPad ? .title3 : .body)
                    .foregroundColor(canGoBack ? .cyan : .gray)
            }
            .disabled(!canGoBack)
            
            // Forward Button
            Button(action: onForward) {
                Image(systemName: "chevron.right")
                    .font(isIPad ? .title3 : .body)
                    .foregroundColor(canGoForward ? .cyan : .gray)
            }
            .disabled(!canGoForward)
            
            Spacer()
            
            // Home Button
            Button(action: onHome) {
                Image(systemName: "house.fill")
                    .font(isIPad ? .title3 : .body)
                    .foregroundColor(.cyan)
            }
            
            Spacer()
            
            // Bookmarks Button
            Button(action: onBookmarks) {
                Image(systemName: "bookmark.fill")
                    .font(isIPad ? .title3 : .body)
                    .foregroundColor(.cyan)
            }
            
            // Share Button
            Button(action: onShare) {
                Image(systemName: "square.and.arrow.up")
                    .font(isIPad ? .title3 : .body)
                    .foregroundColor(.cyan)
            }
            .padding(.bottom, isIPad ? 5 : 0)
        }
        .padding(.horizontal, isIPad ? 20 : 16)
        .padding(.vertical, isIPad ? 12 : 10)
        .background(Color(UIColor.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(UIColor.separator)),
            alignment: .top
        )
    }
}

// MARK: - Bookmarks View
struct BookmarksView: View {
    let onSelectBookmark: (String) -> Void
    let isIPad: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var bookmarks: [Bookmark] = BookmarkManager.shared.getBookmarks()
    @State private var newBookmarkTitle: String = ""
    @State private var newBookmarkURL: String = ""
    @State private var showAddBookmark: Bool = false
    
    var body: some View {
        NavigationView {
            List {
                if bookmarks.isEmpty {
                    VStack(spacing: isIPad ? 20 : 16) {
                        Image(systemName: "bookmark")
                            .font(.system(size: isIPad ? 60 : 40))
                            .foregroundColor(.secondary)
                        Text("No Bookmarks")
                            .font(isIPad ? .title2 : .headline)
                            .foregroundColor(.secondary)
                        Text("Tap + to add a bookmark")
                            .font(isIPad ? .body : .subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, isIPad ? 60 : 40)
                } else {
                    ForEach(bookmarks) { bookmark in
                        Button(action: {
                            onSelectBookmark(bookmark.url)
                            dismiss()
                        }) {
                            HStack(spacing: isIPad ? 16 : 12) {
                                Image(systemName: "bookmark.fill")
                                    .foregroundColor(.cyan)
                                    .font(isIPad ? .body : .subheadline)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(bookmark.title)
                                        .font(isIPad ? .body : .subheadline)
                                        .foregroundColor(.primary)
                                    
                                    Text(bookmark.url)
                                        .font(isIPad ? .caption : .caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                            }
                            .padding(.vertical, isIPad ? 8 : 6)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            BookmarkManager.shared.removeBookmark(bookmarks[index])
                        }
                        bookmarks = BookmarkManager.shared.getBookmarks()
                    }
                }
            }
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showAddBookmark = true
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(.cyan)
                    }
                }
            }
            .sheet(isPresented: $showAddBookmark) {
                AddBookmarkView(
                    onSave: { title, url in
                        BookmarkManager.shared.addBookmark(title: title, url: url)
                        bookmarks = BookmarkManager.shared.getBookmarks()
                        showAddBookmark = false
                    },
                    isIPad: isIPad
                )
            }
        }
    }
}

// MARK: - Add Bookmark View
struct AddBookmarkView: View {
    let onSave: (String, String) -> Void
    let isIPad: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var url: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Title", text: $title)
                        .font(isIPad ? .body : .callout)
                    
                    TextField("URL", text: $url)
                        .font(isIPad ? .body : .callout)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                }
            }
            .navigationTitle("Add Bookmark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(title.isEmpty ? url : title, url)
                    }
                    .disabled(url.isEmpty)
                }
            }
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Bookmark Model
struct Bookmark: Identifiable, Codable {
    let id: UUID
    let title: String
    let url: String
    
    init(id: UUID = UUID(), title: String, url: String) {
        self.id = id
        self.title = title
        self.url = url
    }
}

// MARK: - Bookmark Manager
class BookmarkManager {
    static let shared = BookmarkManager()
    private let bookmarksKey = "BrowserBookmarks"
    
    private init() {}
    
    func getBookmarks() -> [Bookmark] {
        guard let data = UserDefaults.standard.data(forKey: bookmarksKey),
              let bookmarks = try? JSONDecoder().decode([Bookmark].self, from: data) else {
            return defaultBookmarks()
        }
        return bookmarks
    }
    
    func addBookmark(title: String, url: String) {
        var bookmarks = getBookmarks()
        let bookmark = Bookmark(title: title, url: url)
        bookmarks.append(bookmark)
        saveBookmarks(bookmarks)
    }
    
    func removeBookmark(_ bookmark: Bookmark) {
        var bookmarks = getBookmarks()
        bookmarks.removeAll { $0.id == bookmark.id }
        saveBookmarks(bookmarks)
    }
    
    private func saveBookmarks(_ bookmarks: [Bookmark]) {
        if let data = try? JSONEncoder().encode(bookmarks) {
            UserDefaults.standard.set(data, forKey: bookmarksKey)
        }
    }
    
    private func defaultBookmarks() -> [Bookmark] {
        return [
            Bookmark(title: "Google", url: "https://www.google.com"),
            Bookmark(title: "YouTube", url: "https://www.youtube.com"),
            Bookmark(title: "Wikipedia", url: "https://www.wikipedia.org"),
            Bookmark(title: "GitHub", url: "https://www.github.com")
        ]
    }
}
