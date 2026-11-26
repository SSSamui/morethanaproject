// Settings: the unlock check and diary, Screen Time for the tracker, your
// Reminders lists, and the focus clock.

import FamilyControls
import Photos
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var st = PorkSettings()
    @State private var gate = Gate.settings
    @State private var sitesText = ""
    @State private var albums: [String] = []
    @State private var confirmEmpty = false
    @State private var allowed = AuthorizationCenter.shared.authorizationStatus == .approved
    @State private var alwaysOpen = Gate.alwaysOpen
    @State private var pickAlwaysOpen = false
    @State private var focusApps = ScreenTime.focusApps
    @State private var pickFocusApps = false
    @State private var skipToday = Gate.skippedToday
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Ask when I open an app", isOn: $gate.on)
                        .onChange(of: gate.on) { _, on in turnGate(on) }
                    Button("Choose apps that never ask…") { pickAlwaysOpen = true }
                    Text(alwaysOpenSummary).font(.footnote).foregroundStyle(.secondary)
                    Picker("What Pork asks", selection: $gate.level) {
                        ForEach(DiaryLevel.all, id: \.self) { Text(DiaryLevel.title($0)).tag($0) }
                    }
                    Toggle("Skip today", isOn: $skipToday)
                    if let error { Text(error).font(.footnote).foregroundStyle(.red) }
                } header: {
                    Text("🔒 Unlock check and diary")
                } footer: {
                    Text("When you open an app, Pork's screen asks for a photo or a sentence first. It goes in your diary with the time, then your apps open. “Not now” always lets you in. Tap “Choose apps that never ask” and pick **Puppy Pomodoro** (so Pork can open), Messages, Maps, Wallet, Camera, your authenticator and banking apps. Phone and Settings never ask.")
                }

                Section {
                    Stepper("Locked less than \(graceText): no new check", value: graceMinutes, in: 0...5)
                    Stepper("Ask again after \(gate.backupMin) min anyway", value: $gate.backupMin, in: 15...60, step: 5)
                    Toggle("Notice when the phone locks", isOn: $gate.watchLock)
                    Picker("Pork's album in Photos", selection: $st.hiAlbum) {
                        ForEach(albumChoices, id: \.self) { Text($0).tag($0) }
                    }
                } header: {
                    Text("When Pork asks again")
                } footer: {
                    Text("Pork asks again each time you put the phone down and pick it up (locked for more than \(graceText)). To notice the lock, Pork stays awake quietly in the background, which uses a little battery; turn it off and Pork asks again only after \(gate.backupMin) min. After you write, Pork shows one of his photos from the album.")
                }

                Section {
                    if allowed {
                        Label("Screen Time is allowed", systemImage: "checkmark.circle.fill").foregroundStyle(Color.porkFocus)
                    } else {
                        Button("Allow Screen Time") { allowScreenTime() }
                    }
                    Button("Choose focus apps…") { pickFocusApps = true }.disabled(!allowed)
                    Text(focusSummary).font(.footnote).foregroundStyle(.secondary)
                } header: {
                    Text("⏱ Tracker (Screen Time)")
                } footer: {
                    Text("Screen Time lets Pork show your time in each app and ask the unlock check. Focus apps show in green in the tracker (school and work: Outlook, Canvas, Kindle, Notion, Slack, Gmail, Google Calendar, Claude…); everything else is red. Nothing is blocked by the tracker.")
                }

                Section {
                    TextField("School list", text: $st.schoolList)
                        .autocorrectionDisabled()
                    TextField("Routine list", text: $st.routineList)
                        .autocorrectionDisabled()
                    TextField("Inbox list (Tell Pork…)", text: $st.inboxList)
                        .autocorrectionDisabled()
                    Button("Allow Reminders & Calendar") { Task { await TodoStore.shared.requestAccess() } }
                } header: {
                    Text("📝 Reminder (Apple Reminders and Calendar)")
                } footer: {
                    Text("Sticky notes show the school list for the next 7 days (and anything overdue) and the routine list for today only. Add “~3d” to a reminder that needs 3 days, and it shows up 3 days before it's due. The list names must match your lists in Reminders. Pork reminds you 15 minutes before each Calendar event.")
                }

                Section {
                    Stepper("Focus: \(st.focusMin) min", value: $st.focusMin, in: 1...180)
                    Stepper("Break: \(st.breakMin) min", value: $st.breakMin, in: 1...60)
                    Stepper("Bonus treat every \(st.bonusEveryMin) min of extra focus", value: $st.bonusEveryMin, in: 1...60)
                    Toggle("Scratching sound", isOn: $st.sound)
                    Toggle("Pause the clock when the phone locks", isOn: $st.pauseOnLock)
                    TextEditor(text: $sitesText)
                        .font(.system(.footnote, design: .monospaced))
                        .frame(minHeight: 140)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("⏱ Focus clock (focus sites, one per line)")
                } footer: {
                    Text("Only while a focus session runs: every app except your focus apps shows Pork's screen, and Safari only opens these sites. “mit.edu” also covers ocw.mit.edu. A line with a path allows the whole site; youtube.com/@channel lines are skipped (that would open all of YouTube).")
                }

                Section {
                    Button("Empty treat jar", role: .destructive) { confirmEmpty = true }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { save(); dismiss() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .confirmationDialog("Empty the treat jar?", isPresented: $confirmEmpty, titleVisibility: .visible) {
                Button("Empty treat jar", role: .destructive) { model.send(.clearTreats) }
            }
            .familyActivityPicker(isPresented: $pickAlwaysOpen, selection: $alwaysOpen)
            .familyActivityPicker(isPresented: $pickFocusApps, selection: $focusApps)
            .onChange(of: pickAlwaysOpen) { _, open in
                guard !open else { return }
                Gate.alwaysOpen = alwaysOpen
                Gate.apply()
            }
            .onChange(of: pickFocusApps) { _, open in
                guard !open else { return }
                ScreenTime.focusApps = focusApps
                PorkCommands.apply(PorkStore.load())
            }
            .onChange(of: skipToday) { _, on in Gate.skipToday(on) }
            .onAppear {
                st = model.state.settings
                gate = Gate.settings
                sitesText = st.focusSites.joined(separator: "\n")
                loadAlbums()
            }
        }
    }

    private var graceText: String {
        gate.graceSec == 0 ? "0 min" : "\(gate.graceSec / 60) min"
    }

    private var graceMinutes: Binding<Int> {
        Binding(get: { gate.graceSec / 60 }, set: { gate.graceSec = $0 * 60 })
    }

    private var albumChoices: [String] {
        albums.contains(st.hiAlbum) ? albums : [st.hiAlbum] + albums
    }

    private var alwaysOpenSummary: String {
        let n = alwaysOpen.applicationTokens.count
        if n == 0 { return "No apps picked yet. Pick Puppy Pomodoro first, or Pork's own screen asks too." }
        return "\(n) app\(n == 1 ? "" : "s") never ask."
    }

    private var focusSummary: String {
        let n = focusApps.applicationTokens.count
        return n == 0 ? "No focus apps yet." : "\(n) focus app\(n == 1 ? "" : "s")."
    }

    private func save() {
        var new = st
        new.focusSites = sitesText.components(separatedBy: CharacterSet(charactersIn: " ,\n\t"))
        model.send(.settings(new))
        let was = Gate.settings
        Gate.settings = gate
        if gate.on && !was.on { Gate.open() } // starts after the next time you lock the phone
        Gate.apply()
        Gate.scheduleDay()
        LockWatcher.shared.update(PorkStore.load())
    }

    private func turnGate(_ on: Bool) {
        error = nil
        guard on else {
            Gate.stop()
            return
        }
        if !allowed { allowScreenTime() }
    }

    private func allowScreenTime() {
        Task {
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                ScreenTime.isOn = true
            } catch {
                self.error = "Screen Time wasn't allowed: \(error.localizedDescription)"
                gate.on = false
            }
            allowed = AuthorizationCenter.shared.authorizationStatus == .approved
        }
    }

    private func loadAlbums() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            guard status == .authorized || status == .limited else { return }
            let found = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
            var names: [String] = []
            found.enumerateObjects { c, _, _ in
                if let t = c.localizedTitle, !names.contains(t) { names.append(t) }
            }
            DispatchQueue.main.async { albums = names.sorted() }
        }
    }
}
