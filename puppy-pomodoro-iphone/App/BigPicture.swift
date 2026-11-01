// The big picture: every homework, project and quiz with a due date over the
// next 3 weeks, as bars from today to the due day. A task that needs several
// days ("Lab report ~3d") shows its work days and when to start.

import SwiftUI

struct BigPictureView: View {
    @ObservedObject var todos: TodoStore
    private let span = 21 // days shown

    var body: some View {
        let today = Calendar.current.startOfDay(for: Date())
        let end = today.addingTimeInterval(TimeInterval(span * 86400))
        let items = todos.snapshot.upcoming.filter { ($0.due ?? end) < end }
        let later = todos.snapshot.upcoming.count - items.count
        VStack(alignment: .leading, spacing: 12) {
            if items.isEmpty {
                Text("Nothing due in the next 3 weeks 🎉").font(.footnote).foregroundStyle(.secondary)
            } else {
                ruler(today)
                ForEach(items) { item in row(item, today: today) }
                if later > 0 {
                    Text("+\(later) due later").font(.footnote).foregroundStyle(.secondary)
                }
                Text("Tip: add how many days a task needs to its title, like “Lab report ~3d”. Pork then shows it in Today when it's time to start.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    /// Week labels over the bars.
    private func ruler(_ today: Date) -> some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                ForEach(0..<4) { w in
                    let day = today.addingTimeInterval(TimeInterval(w * 7 * 86400))
                    Text(w == 0 ? "Today" : day.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.caption2.bold()).foregroundStyle(.secondary)
                        .offset(x: g.size.width * CGFloat(w * 7) / CGFloat(span))
                }
            }
        }
        .frame(height: 14)
    }

    private func row(_ item: TodoItem, today: Date) -> some View {
        let due = item.due ?? today
        let daysLeft = Calendar.current.dateComponents([.day], from: today, to: Calendar.current.startOfDay(for: due)).day ?? 0
        let color: Color = daysLeft <= 1 ? .porkOver : daysLeft <= 3 ? .orange : .porkFocus
        return VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(item.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                Spacer()
                Text(label(item, daysLeft: daysLeft)).font(.caption.weight(.semibold)).foregroundStyle(color)
            }
            GeometryReader { g in
                let w = g.size.width
                let x = { (d: Date) -> CGFloat in
                    let days = d.timeIntervalSince(today) / 86400
                    return w * CGFloat(min(Double(span), max(0, days)) / Double(span))
                }
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.15))
                    Capsule().fill(color.opacity(0.3)).frame(width: max(6, x(due) + 4))
                    if let start = item.startBy {
                        Capsule().fill(color)
                            .frame(width: max(6, x(due) - x(start) + 4))
                            .offset(x: x(start))
                    }
                    Circle().fill(color).frame(width: 10, height: 10).offset(x: max(0, x(due) - 3))
                }
            }
            .frame(height: 10)
        }
    }

    private func label(_ item: TodoItem, daysLeft: Int) -> String {
        let when = daysLeft < 0 ? "overdue" : daysLeft == 0 ? "due today" : daysLeft == 1 ? "due tomorrow" : "in \(daysLeft) days"
        if let days = item.days, let start = item.startBy, daysLeft > 0 {
            let startDay = Calendar.current.startOfDay(for: start)
            let s = startDay <= Calendar.current.startOfDay(for: Date()) ? "start now!" : "start " + start.formatted(.dateTime.weekday(.abbreviated))
            return "\(when) · needs \(days)d · \(s)"
        }
        return when
    }
}
