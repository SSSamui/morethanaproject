// Pork's room, drawn by the same picture code as the Safari version
// (room.html, built from tools/pork.js), with all his animations.

import SwiftUI
import WebKit

struct RoomView: UIViewRepresentable {
    var pose: Pose
    var goal: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let web = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.backgroundColor = .clear
        web.scrollView.isScrollEnabled = false
        web.isUserInteractionEnabled = false
        web.navigationDelegate = context.coordinator
        if let url = Bundle.main.url(forResource: "room", withExtension: "html") {
            web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        context.coordinator.show(pose: pose, goal: goal, in: web)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        private var loaded = false
        private var wanted = (pose: Pose.sleep, goal: false)
        private var shown: (pose: Pose, goal: Bool)?

        func show(pose: Pose, goal: Bool, in web: WKWebView) {
            wanted = (pose, goal)
            guard loaded, shown?.pose != pose || shown?.goal != goal else { return }
            shown = wanted
            web.evaluateJavaScript("setPork('\(pose.rawValue)', \(goal))")
        }

        func webView(_ web: WKWebView, didFinish navigation: WKNavigation!) {
            loaded = true
            show(pose: wanted.pose, goal: wanted.goal, in: web)
        }
    }
}
