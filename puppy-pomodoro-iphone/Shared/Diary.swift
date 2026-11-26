// Pork's diary: one entry each time you pass the unlock check (a sentence,
// a photo, or "not now"). Stored in the App Group so the blocked-app buttons
// can add to it too; the app also keeps a readable copy in Files
// (see App/DiaryExport.swift).

import Foundation

struct DiaryEntry: Codable, Identifiable, Hashable {
    enum Kind: String, Codable { case text, photo, skip }

    var id = UUID()
    var started: Date            // when the check began (you picked up the phone)
    var saved: Date              // when you finished
    var kind: Kind
    var text = ""
    var mood: String?            // level 3: how you feel
    var photo: String?           // file name in the diary's Photos folder
    var prompt: String?          // the question Pork asked
    var level = 1
}

struct DiaryDay: Identifiable, Hashable {
    let day: String              // "2026-11-26"
    let date: Date
    let entries: [DiaryEntry]    // newest first
    var id: String { day }
}

enum Diary {
    private static var root: URL {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: PorkGroup.id)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Diary", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static var file: URL { root.appendingPathComponent("diary.json") }

    static var photos: URL {
        let dir = root.appendingPathComponent("Photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func photoURL(_ name: String) -> URL { photos.appendingPathComponent(name) }

    /// Every entry, oldest first.
    static func all() -> [DiaryEntry] {
        var out: [DiaryEntry] = []
        NSFileCoordinator().coordinate(readingItemAt: file, options: [], error: nil) { url in
            if let data = try? Data(contentsOf: url),
               let list = try? decoder.decode([DiaryEntry].self, from: data) { out = list }
        }
        return out
    }

    static func add(_ entry: DiaryEntry) {
        NSFileCoordinator().coordinate(writingItemAt: file, options: [], error: nil) { url in
            var list: [DiaryEntry] = []
            if let data = try? Data(contentsOf: url),
               let old = try? decoder.decode([DiaryEntry].self, from: data) { list = old }
            list.append(entry)
            if let data = try? encoder.encode(list) { try? data.write(to: url, options: .atomic) }
        }
        PorkGroup.defaults.set(Date(), forKey: "diaryChanged")
    }

    /// Saves a JPEG and returns its file name.
    static func savePhoto(_ jpeg: Data, at date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH.mm.ss"
        let name = f.string(from: date) + ".jpg"
        try? jpeg.write(to: photoURL(name), options: .atomic)
        return name
    }

    /// Entries grouped by day, newest day first.
    static func days(_ entries: [DiaryEntry] = all(), calendar: Calendar = .current) -> [DiaryDay] {
        let groups = Dictionary(grouping: entries) { Days.key($0.started, calendar: calendar) }
        return groups.map { key, list in
            DiaryDay(day: key, date: calendar.startOfDay(for: list[0].started),
                     entries: list.sorted { $0.started > $1.started })
        }
        .sorted { $0.day > $1.day }
    }

    /// Days you wrote something (not just "not now") in the last 7 days, today included.
    static func daysWritten(lastWeek entries: [DiaryEntry], now: Date = Date(), calendar: Calendar = .current) -> Int {
        let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? now
        let keys = Set(entries.filter { $0.kind != .skip && $0.started >= start }.map { Days.key($0.started, calendar: calendar) })
        return keys.count
    }

    private static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}

/// What Pork asks, by level. Move up a level in Settings when it feels easy.
enum DiaryLevel {
    static let all = [1, 2, 3, 4]

    static func title(_ level: Int) -> String {
        switch level {
        case 2: return "One sentence"
        case 3: return "How you feel + one sentence"
        case 4: return "A short paragraph"
        default: return "A photo or one sentence"
        }
    }

    /// The short line on Pork's blocked-app screen.
    static func ask(_ level: Int) -> String {
        switch level {
        case 2: return "Write Pork one sentence."
        case 3: return "Tell Pork how you feel, in one sentence."
        case 4: return "Write Pork a few sentences."
        default: return "Take a photo or write Pork one sentence."
        }
    }

    /// Level 4 wants about 3 sentences.
    static let paragraphWords = 20

    static func words(_ text: String) -> Int {
        text.split { $0 == " " || $0 == "\n" }.count
    }

    /// Anything counts, even "ok". Only level 4 asks for a bit more.
    static func isEnough(_ text: String, level: Int) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return false }
        return level < 4 || words(t) >= paragraphWords
    }

    static let feelings = ["😄 great", "🙂 good", "😐 okay", "😴 tired", "😟 worried", "😤 annoyed", "😢 sad"]

    /// A different small question each time, so it doesn't get boring.
    static let prompts = [
        "What are you about to do?",
        "What's one thing you saw today?",
        "How's your energy right now?",
        "What's on your mind?",
        "What did you just finish?",
        "What's one thing you're looking forward to?",
        "Where are you right now?",
        "What would make the next hour good?",
        "Who did you talk to today?",
        "What's bugging you a little?",
        "What did you eat last?",
        "What's one small win from today?"
    ]

    static func prompt(_ seed: Int) -> String { prompts[abs(seed) % prompts.count] }
}
