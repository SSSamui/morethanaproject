// Fun notes and the page that opens only that one link.
// A YouTube video plays in the YouTube player (no YouTube app, no other
// videos); a Reddit post or an X account opens inside Puppy Pomodoro, and
// links to anywhere else are stopped. Kindle links open the Kindle app.

import SwiftUI
import WebKit

/// The "fun" list as purple sticky notes. Tap one to open its link.
struct FunBoard: View {
    @ObservedObject var todos: TodoStore
    @State private var open: TodoItem?

    var body: some View {
        let fun = todos.snapshot.fun
        Group {
            if fun.isEmpty {
                Text("Add things you'd love to do in spare time to a Reminders list called “\(PorkStore.load().settings.funList)”, with the link like: Robotics talk open:https://youtu.be/…")
                    .font(.footnote).foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                    ForEach(fun) { item in
                        Button { start(item) } label: { FunNote(item: item) }
                            .buttonStyle(.plain)
                    }
                }
            }
        }
        .sheet(item: $open) { item in
            FunViewer(item: item) { todos.complete(item) }
        }
    }

    private func start(_ item: TodoItem) {
        guard let link = item.link, link.scheme != "about" else { return }
        if FunLink.opensOutside(link) {
            UIApplication.shared.open(link)
        } else {
            open = item
        }
    }
}

struct FunNote: View {
    let item: TodoItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.title)
                .font(.system(.callout, design: .rounded).weight(.semibold))
                .foregroundStyle(.black.opacity(0.85))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Text(kind).font(.caption2.weight(.semibold)).foregroundStyle(.black.opacity(0.55))
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .topLeading)
        .background(Color(red: 0.88, green: 0.80, blue: 1.0), in: RoundedRectangle(cornerRadius: 4))
        .shadow(color: .black.opacity(0.18), radius: 3, x: 1, y: 2)
        .rotationEffect(.degrees(Double(item.title.count % 5) - 2))
    }

    private var kind: String {
        guard let link = item.link, link.scheme != "about" else { return "🎈 fun" }
        if FunLink.youTubeID(link) != nil { return "▶️ video" }
        if FunLink.opensOutside(link) { return "📖 opens the app" }
        return "🎈 " + (link.host ?? "link").replacingOccurrences(of: "www.", with: "")
    }
}

/// Opens one fun link and nothing else.
struct FunViewer: View {
    let item: TodoItem
    let done: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var stopped = false

    var body: some View {
        NavigationStack {
            Group {
                if let link = item.link {
                    FunWebView(start: link) { stopped = true }
                        .ignoresSafeArea(edges: .bottom)
                }
            }
            .navigationTitle(item.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done ✓") { done(); dismiss() }
                }
            }
            .overlay(alignment: .bottom) {
                if stopped {
                    Text("Only this fun link opens here 🐾")
                        .font(.footnote.bold())
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.bottom, 24)
                        .onTapGesture { stopped = false }
                }
            }
        }
    }
}

struct FunWebView: UIViewRepresentable {
    let start: URL
    let blocked: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(start: start, blocked: blocked) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = context.coordinator
        web.uiDelegate = context.coordinator
        web.load(URLRequest(url: FunLink.viewerURL(start)))
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let start: URL
        let blocked: () -> Void
        init(start: URL, blocked: @escaping () -> Void) {
            self.start = start
            self.blocked = blocked
        }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Pictures, videos and players inside the page are fine; only the
            // page itself may not go somewhere else.
            guard action.targetFrame?.isMainFrame ?? true, let url = action.request.url,
                  url.scheme == "http" || url.scheme == "https" else {
                decisionHandler(.allow)
                return
            }
            if FunLink.allows(url, from: start) || url == FunLink.viewerURL(start) {
                decisionHandler(.allow)
            } else {
                decisionHandler(.cancel)
                DispatchQueue.main.async { self.blocked() }
            }
        }

        // Links that want a new window are stopped too.
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            DispatchQueue.main.async { self.blocked() }
            return nil
        }
    }
}
