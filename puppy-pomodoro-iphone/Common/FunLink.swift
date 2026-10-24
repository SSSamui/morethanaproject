// "fun" list items: a reminder with a link, like
//   "Watch the MIT robotics talk open:https://youtu.be/abc123XYZ00"
// The link can also be in the reminder's notes or URL field.
// Only that link opens (inside Puppy Pomodoro); the rest of YouTube, Reddit
// or X stays a distraction.

import Foundation

enum FunLink {
    /// The title without the "open:…" part, and the link.
    static func parse(title: String, notes: String?, url: URL?) -> (title: String, link: URL?) {
        var clean = title
        var link: URL? = url
        for text in [title, notes ?? ""] {
            if let found = find(in: text) {
                if link == nil { link = found.url }
                if text == title { clean.removeSubrange(found.range) }
            }
        }
        clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty { clean = link?.host ?? title }
        return (clean, link)
    }

    private static func find(in text: String) -> (url: URL, range: Range<String.Index>)? {
        // "open:https://…", "open: kindle://…", or a bare https:// link
        let pattern = #"(?i)(open:\s*)?([a-z][a-z0-9+.-]*://[^\s]+|www\.[^\s]+)"#
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let whole = Range(m.range, in: text),
              let linkRange = Range(m.range(at: 2), in: text) else { return nil }
        var raw = String(text[linkRange])
        if raw.lowercased().hasPrefix("www.") { raw = "https://" + raw }
        guard let url = URL(string: raw) else { return nil }
        return (url, whole)
    }

    /// A YouTube video id from youtube.com/watch?v=…, youtu.be/…, /shorts/…
    static func youTubeID(_ url: URL) -> String? {
        let host = (url.host ?? "").lowercased().replacingOccurrences(of: "www.", with: "").replacingOccurrences(of: "m.", with: "")
        let parts = url.path.split(separator: "/").map(String.init)
        if host == "youtu.be" { return parts.first }
        guard host.hasSuffix("youtube.com") else { return nil }
        if let v = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "v" })?.value {
            return v
        }
        if parts.count >= 2, ["shorts", "embed", "live"].contains(parts[0]) { return parts[1] }
        return nil
    }

    /// Where Pork opens it: a YouTube video plays in the YouTube player only
    /// (no YouTube app, no other videos).
    static func viewerURL(_ url: URL) -> URL {
        if let id = youTubeID(url) {
            return URL(string: "https://www.youtube-nocookie.com/embed/\(id)?playsinline=1&rel=0")!
        }
        return url
    }

    /// May the page inside Pork's viewer go to `next`? Only the same site and
    /// the same place (a Reddit post, an X account, a project page).
    static func allows(_ next: URL, from start: URL) -> Bool {
        func host(_ u: URL) -> String {
            var h = (u.host ?? "").lowercased()
            for p in ["www.", "m.", "old.", "mobile."] where h.hasPrefix(p) { h.removeFirst(p.count) }
            return h
        }
        if youTubeID(start) != nil { return host(next).hasSuffix("youtube-nocookie.com") }
        guard host(next) == host(start) else { return false }
        let startPath = start.path.hasSuffix("/") ? String(start.path.dropLast()) : start.path
        if startPath.isEmpty { return true }
        return next.path == startPath || next.path.hasPrefix(startPath + "/")
    }

    /// Links for apps (kindle://, the Kindle web reader…) open in that app.
    static func opensOutside(_ url: URL) -> Bool {
        let scheme = (url.scheme ?? "").lowercased()
        if scheme != "http" && scheme != "https" { return true }
        let h = (url.host ?? "").lowercased()
        return h.hasSuffix("read.amazon.com") || h.hasSuffix("kindle.amazon.com")
    }
}
