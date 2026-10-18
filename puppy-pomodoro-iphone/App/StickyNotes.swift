// Sticky notes: to-dos for today and the next days, and a big note for the
// calendar event happening now.

import SwiftUI

enum NoteColor {
    static let today = Color(red: 1.0, green: 0.95, blue: 0.62)   // yellow
    static let days: [Color] = [
        Color(red: 1.0, green: 0.83, blue: 0.88),   // pink
        Color(red: 0.81, green: 0.96, blue: 0.82),  // green
        Color(red: 0.81, green: 0.91, blue: 1.0),   // blue
        Color(red: 1.0, green: 0.88, blue: 0.72),   // orange
        Color(red: 0.90, green: 0.85, blue: 1.0),   // purple
        Color(red: 0.86, green: 0.95, blue: 0.95)   // mint
    ]
}

/// Today's notes, then one row per day.
struct StickyBoard: View {
    @ObservedObject var todos: TodoStore
    var showUpcoming = true

    var body: some View {
        let snap = todos.snapshot
        VStack(alignment: .leading, spacing: 14) {
            if todos.needsAccess {
                VStack(alignment: .leading, spacing: 8) {
                    Text("📝 See your to-dos from Reminders and your Calendar events here.")
                        .font(.footnote)
                    Button("Allow Reminders & Calendar") { Task { await todos.requestAccess() } }
                        .buttonStyle(.borderedProminent).tint(.porkFocus)
                }
            } else {
                if !snap.missingLists.isEmpty {
                    Text("No Reminders list named \(snap.missingLists.map { "“\($0)”" }.joined(separator: " or ")). Make it in Reminders, or change the name in Settings.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                notes("Today", snap.today, NoteColor.today)
                if snap.today.isEmpty && snap.missingLists.count < 2 {
                    Text("Nothing left for today 🎉").font(.footnote).foregroundStyle(.secondary)
                }
                if showUpcoming {
                    ForEach(Array(snap.days.enumerated()), id: \.element.id) { i, day in
                        notes(dayTitle(day.date), day.items, NoteColor.days[i % NoteColor.days.count])
                    }
                    notes("No due date", snap.noDate, Color(white: 0.93))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func notes(_ title: String, _ items: [TodoItem], _ color: Color) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.headline)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                    ForEach(items) { item in
                        StickyNote(item: item, color: color) { todos.complete(item) }
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
        }
    }

    private func dayTitle(_ date: Date) -> String {
        if Calendar.current.isDateInTomorrow(date) { return "Tomorrow" }
        return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}

struct StickyNote: View {
    let item: TodoItem
    let color: Color
    let done: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text(item.title)
                    .font(.system(.callout, design: .rounded).weight(.semibold))
                    .foregroundStyle(.black.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Button(action: done) {
                    Image(systemName: "checkmark.circle")
                        .font(.title3)
                        .foregroundStyle(.black.opacity(0.45))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Mark “\(item.title)” done")
            }
            Spacer(minLength: 0)
            if let tag {
                Text(tag).font(.caption2.weight(.semibold))
                    .foregroundStyle(item.overdue() ? Color.porkOver : .black.opacity(0.55))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .topLeading)
        .background(color, in: RoundedRectangle(cornerRadius: 4))
        .shadow(color: .black.opacity(0.18), radius: 3, x: 1, y: 2)
        .rotationEffect(.degrees(tilt))
    }

    private var tag: String? {
        var parts: [String] = []
        if item.overdue(), let due = item.due {
            parts.append("⚠️ overdue · " + due.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
        } else if item.hasTime, let due = item.due {
            parts.append(due.formatted(date: .omitted, time: .shortened))
        }
        if item.routine { parts.append("🔁 routine") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// A small tilt that stays the same for each note.
    private var tilt: Double {
        let n = item.id.unicodeScalars.reduce(0) { ($0 + Int($1.value)) % 97 }
        return Double(n % 5) - 2
    }
}

/// The calendar event right now, as a big sticky note.
struct BigEventNote: View {
    let event: NowEvent

    var body: some View {
        VStack(spacing: 8) {
            Text(badge).font(.caption.weight(.heavy)).tracking(1.2)
                .foregroundStyle(Color.porkOver)
            Text(event.title)
                .font(.system(.title, design: .rounded).weight(.bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.black.opacity(0.85))
            if !event.allDay {
                Text("\(event.start.formatted(date: .omitted, time: .shortened)) – \(event.end.formatted(date: .omitted, time: .shortened))")
                    .font(.headline).foregroundStyle(.black.opacity(0.6))
            }
            if let location = event.location {
                Text("📍 \(location)").font(.subheadline).foregroundStyle(.black.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 26).padding(.horizontal, 20)
        .frame(maxWidth: 360)
        .frame(maxWidth: .infinity)
        .background(NoteColor.today, in: RoundedRectangle(cornerRadius: 6))
        .shadow(color: .black.opacity(0.22), radius: 6, x: 2, y: 4)
        .rotationEffect(.degrees(-1.5))
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private var badge: String {
        if event.allDay { return "📅 TODAY" }
        let now = Date()
        if event.start <= now { return "📅 NOW" }
        let mins = Int(ceil(event.start.timeIntervalSince(now) / 60))
        return "📅 IN \(mins) MIN"
    }
}
