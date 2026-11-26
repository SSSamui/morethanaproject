// A readable copy of the diary in the Files app: one file per day
// ("2026-11-26.md") and a Photos folder.
// - With iCloud turned on for the app (optional, see the README): iCloud
//   Drive → Pork Diary. It survives deleting the app and shows on the Mac.
// - Otherwise: On My iPhone → Puppy Pomodoro → Pork Diary.

import Foundation

enum DiaryExport {
    /// Where the copy goes (iCloud Drive if the app has it, else On My iPhone).
    static func folder() -> URL {
        let fm = FileManager.default
        let base = fm.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents", isDirectory: true)
            ?? fm.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Pork Diary", isDirectory: true)
        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    static var inICloud: Bool { PorkStore.defaults.bool(forKey: "diaryInICloud") }

    /// Rewrites the files for the days that changed (today and yesterday are
    /// always rewritten; older days only the first time).
    static func write() async {
        await Task.detached(priority: .utility) {
            let fm = FileManager.default
            let dir = folder()
            PorkStore.defaults.set(fm.url(forUbiquityContainerIdentifier: nil) != nil, forKey: "diaryInICloud")
            let photos = dir.appendingPathComponent("Photos", isDirectory: true)
            try? fm.createDirectory(at: photos, withIntermediateDirectories: true)
            let recent = Set([Days.key(Date()), Days.key(Date().addingTimeInterval(-86_400))])
            for day in Diary.days() {
                let file = dir.appendingPathComponent(day.day + ".md")
                if fm.fileExists(atPath: file.path) && !recent.contains(day.day) { continue }
                try? markdown(day).write(to: file, atomically: true, encoding: .utf8)
                for name in day.entries.compactMap(\.photo) {
                    let dst = photos.appendingPathComponent(name)
                    if !fm.fileExists(atPath: dst.path) { try? fm.copyItem(at: Diary.photoURL(name), to: dst) }
                }
            }
        }.value
    }

    static func markdown(_ day: DiaryDay) -> String {
        let title = day.date.formatted(.dateTime.weekday(.wide).month(.wide).day().year())
        var out = "# \(title)\n\n"
        for e in day.entries.sorted(by: { $0.started < $1.started }) {
            let time = Dur.clock(e.started)
            switch e.kind {
            case .skip:
                out += "- \(time) — ⏭ skipped\n"
            case .text, .photo:
                var line = "- \(time) — "
                if let mood = e.mood { line += "\(mood) · " }
                line += e.text.isEmpty ? "📷" : e.text.replacingOccurrences(of: "\n", with: " ")
                if let q = e.prompt { line += "  _(\(q))_" }
                out += line + "\n"
                if let photo = e.photo { out += "  ![photo](Photos/\(photo.replacingOccurrences(of: " ", with: "%20")))\n" }
            }
        }
        return out
    }
}
