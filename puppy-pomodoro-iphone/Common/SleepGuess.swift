// When you put the phone down for the night and when you picked it up again,
// guessed from when the phone was used: the longest quiet stretch (3 hours or
// more) between yesterday evening and now.

import Foundation

struct UseMark: Equatable {
    var start: Date
    var end: Date
}

enum SleepGuess {
    static func find(_ uses: [UseMark], minGap: TimeInterval = 3 * 3600) -> (sleep: Date, wake: Date)? {
        let sorted = uses.sorted { $0.start < $1.start }
        guard sorted.count >= 2 else { return nil }
        var best: (sleep: Date, wake: Date)?
        var lastEnd = sorted[0].end
        for use in sorted.dropFirst() {
            let gap = use.start.timeIntervalSince(lastEnd)
            if gap >= minGap, gap > (best.map { $0.wake.timeIntervalSince($0.sleep) } ?? 0) {
                best = (lastEnd, use.start)
            }
            lastEnd = max(lastEnd, use.end)
        }
        return best
    }
}
