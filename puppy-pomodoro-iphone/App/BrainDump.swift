// "Tell Pork…": get a thought out of your head in 2 seconds. It goes to the
// Reminders list "Inbox"; sort it later into school / routine / fun.

import SwiftUI
import UserNotifications

struct BrainDumpSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var todos: TodoStore
    @State private var text = ""
    @State private var saved: [String] = []
    @FocusState private var typing: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                TextField("What's on your mind?", text: $text, axis: .vertical)
                    .font(.title3)
                    .lineLimit(1...4)
                    .padding(14)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                    .focused($typing)
                    .submitLabel(.done)
                    .onSubmit(save)
                Button(action: save) {
                    Text("💭 Tell Pork").font(.headline).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).tint(.porkFocus).controlSize(.large)
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                ForEach(saved, id: \.self) { s in
                    Text("✓ \(s)").font(.footnote).foregroundStyle(.secondary)
                }
                Text("It's out of your head now. Pork keeps it in your Reminders “\(PorkStore.load().settings.inboxList)” list until you sort it.")
                    .font(.footnote).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(20)
            .navigationTitle("Tell Pork…")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
            .onAppear { typing = true }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        todos.add(t)
        saved.insert(t, at: 0)
        text = ""
    }
}

/// Inbox thoughts on the board, each with buttons to sort it.
struct InboxSorter: View {
    @ObservedObject var todos: TodoStore

    var body: some View {
        let st = PorkStore.load().settings
        VStack(alignment: .leading, spacing: 10) {
            ForEach(todos.snapshot.inbox) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title).font(.subheadline.weight(.semibold))
                    HStack(spacing: 6) {
                        sortButton("📚", st.schoolList, item)
                        sortButton("🔁", st.routineList, item)
                        sortButton("🎈", st.funList, item)
                        Button("✓") { todos.complete(item) }.buttonStyle(.bordered)
                    }
                    .font(.caption)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(white: 0.93), in: RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(.black.opacity(0.85))
            }
        }
    }

    private func sortButton(_ icon: String, _ list: String, _ item: TodoItem) -> some View {
        Button("\(icon) \(list)") { todos.move(item, to: list) }.buttonStyle(.bordered).lineLimit(1)
    }
}

enum InboxReminder {
    /// Sunday 6 pm: "Sort Pork's inbox".
    static func schedule() {
        let content = UNMutableNotificationContent()
        content.title = "Sort Pork's inbox 💭"
        content.body = "Give this week's thoughts a home: school, routine or fun. Takes 2 minutes."
        content.userInfo = ["open": "board"]
        var when = DateComponents()
        when.weekday = 1
        when.hour = 18
        when.minute = 0
        UNUserNotificationCenter.current().add(UNNotificationRequest(
            identifier: "pork.inboxSort", content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: true)))
    }
}

/// Pork jumps for joy when a to-do is done.
struct Celebration: View {
    var body: some View {
        VStack(spacing: 8) {
            Image("PorkPace").resizable().scaledToFit().frame(height: 110)
                .phaseAnimator([0.0, -24.0]) { v, y in v.offset(y: y) } animation: { _ in .spring(duration: 0.35) }
            Text("🎉 Done! Pork is so proud").font(.title3.bold())
            Text("✅ \(DoneToday.count) finished today").font(.subheadline)
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        .transition(.scale.combined(with: .opacity))
    }
}
