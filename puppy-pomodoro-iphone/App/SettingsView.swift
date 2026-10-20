// Settings: clock, blocking (Screen Time), focus sites, to-dos, Pork's
// check-ins, treat jar.

import Photos
import SwiftUI
#if !LITE
import FamilyControls
#endif

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var st = PorkSettings()
    @State private var sitesText = ""
    @State private var albums: [String] = []
    @State private var confirmEmpty = false
    @State private var showShortcutHelp = false
    #if !LITE
    @State private var blocking = ScreenTime.isOn
    @State private var focusApps = ScreenTime.focusApps
    @State private var pickApps = false
    @State private var countApps = ScreenTime.countApps
    @State private var pickCount = false
    @State private var screenTimeError: String?
    #endif

    var body: some View {
        NavigationStack {
            Form {
                Section("Clock") {
                    Stepper("Focus: \(st.focusMin) min", value: $st.focusMin, in: 1...180)
                    Stepper("Break: \(st.breakMin) min", value: $st.breakMin, in: 1...60)
                    Stepper("Bonus treat every \(st.bonusEveryMin) min of extra focus", value: $st.bonusEveryMin, in: 1...60)
                    Toggle("Scratching sound", isOn: $st.sound)
                    Toggle("Pause the clock when the phone locks", isOn: $st.pauseOnLock)
                }

                #if !LITE
                Section {
                    Toggle("Block distractions during focus", isOn: $blocking)
                        .onChange(of: blocking) { _, on in turnBlocking(on) }
                    Button("Choose focus apps…") { pickApps = true }
                        .disabled(!blocking)
                    Button("Choose what counts as phone time…") { pickCount = true }
                        .disabled(!blocking)
                    Text("For today's promise: tap “All Apps & Categories” in the list. Focus apps are left out again, so only play time counts.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text(appsSummary).font(.footnote).foregroundStyle(.secondary)
                    Toggle("Only focus apps late at night", isOn: $st.nightOn)
                        .disabled(!blocking)
                    if st.nightOn {
                        DatePicker("From", selection: nightTime(\.nightStart), displayedComponents: .hourAndMinute)
                        DatePicker("Until", selection: nightTime(\.nightEnd), displayedComponents: .hourAndMinute)
                    }
                    if let screenTimeError {
                        Text(screenTimeError).font(.footnote).foregroundStyle(.red)
                    }
                } header: {
                    Text("Blocking (Screen Time)")
                } footer: {
                    Text("During focus every app except your focus apps shows Pork's screen. After the focus goal, that screen has a “Start my break” button. When the break is over it comes back with “Let Pork out”. Late at night (12:00 am to 6:00 am unless you change it) only focus apps and sites open, even without a focus session. Pick your focus apps: Outlook, WeChat, Kindle, Gmail, Google Drive, Google Tasks, Google Calendar, Calendar, Reminders, Handshake, Slack, Messages, Phone, Canvas, Claude, Gemini, ChatGPT and Puppy Pomodoro. Everything else is a distraction. (Phone calls, alarms and Settings always work.)")
                }
                #endif

                Section {
                    TextEditor(text: $sitesText)
                        .font(.system(.footnote, design: .monospaced))
                        .frame(minHeight: 180)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Focus sites (one per line)")
                } footer: {
                    Text("During focus, Safari only opens these sites. “mit.edu” also covers ocw.mit.edu and other subdomains. On iPhone a line with a path allows the whole site (sssamui.github.io/morethanaproject/danmu allows sssamui.github.io). YouTube players inside focus sites (like the danmu site) play; lines like youtube.com/@mitocw are skipped, because that would open all of YouTube. Add youtube.com if you need YouTube itself.")
                }

                Section {
                    TextField("School list", text: $st.schoolList)
                        .autocorrectionDisabled()
                    TextField("Routine list", text: $st.routineList)
                        .autocorrectionDisabled()
                    Button("Allow Reminders & Calendar") { Task { await TodoStore.shared.requestAccess() } }
                } header: {
                    Text("To-dos (Apple Reminders)")
                } footer: {
                    Text("Sticky notes show the school list for the next 7 days (and anything overdue) and the routine list for today only. The list names must match your lists in Reminders. Tap ✓ on a note to mark it done in Reminders.")
                }

                Section {
                    Toggle("Pork's check-ins", isOn: $st.hiEnabled)
                    Stepper("Pork reminder after \(st.nudgeMin) min", value: $st.nudgeMin, in: 1...60)
                    Stepper("To-dos after \(st.notesMin) min", value: $st.notesMin, in: (st.nudgeMin + 1)...120)
                    Picker("Pork's album in Photos", selection: $st.hiAlbum) {
                        ForEach(albumChoices, id: \.self) { Text($0).tag($0) }
                    }
                    Toggle("Videos without sound", isOn: $st.hiMuted)
                    Button("Try the check-in") {
                        save()
                        dismiss()
                        model.showHi = true
                    }
                    Button("How to set up Shortcuts (pick-up, 12 am Outlook, 6 pm WeChat)") { showShortcutHelp = true }
                } header: {
                    Text("Pork's check-ins")
                } footer: {
                    Text("When you open a distraction app, Pork reminds you after \(st.nudgeMin) min and shows your to-dos after \(st.notesMin) min. If a Calendar event is on, it shows right away as a big sticky note. At 12 am Outlook opens and at 6 pm WeChat opens if to-dos are left. This needs the Shortcuts automations (button above).")
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
            .sheet(isPresented: $showShortcutHelp) { ShortcutHelpView() }
            #if !LITE
            .familyActivityPicker(isPresented: $pickApps, selection: $focusApps)
            .familyActivityPicker(isPresented: $pickCount, selection: $countApps)
            .onChange(of: pickCount) { _, open in
                guard !open else { return }
                ScreenTime.countApps = countApps
                if let plan = DayPlans.today() { ScreenTime.startPromise(plan) }
            }
            .onChange(of: pickApps) { _, open in
                guard !open else { return }
                ScreenTime.focusApps = focusApps
                PorkCommands.apply(PorkStore.load()) // also updates the late-night block
            }
            #endif
            .onAppear {
                st = model.state.settings
                sitesText = st.focusSites.joined(separator: "\n")
                loadAlbums()
            }
        }
    }

    private var albumChoices: [String] {
        albums.contains(st.hiAlbum) ? albums : [st.hiAlbum] + albums
    }

    private func save() {
        var new = st
        new.focusSites = sitesText.components(separatedBy: CharacterSet(charactersIn: " ,\n\t"))
        model.send(.settings(new))
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

    #if !LITE
    /// A time picker for minutes after midnight.
    private func nightTime(_ key: WritableKeyPath<PorkSettings, Int>) -> Binding<Date> {
        Binding(
            get: { Calendar.current.date(from: DateComponents(hour: st[keyPath: key] / 60, minute: st[keyPath: key] % 60)) ?? Date() },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                st[keyPath: key] = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            })
    }

    private var appsSummary: String {
        let a = focusApps.applicationTokens.count, c = focusApps.categoryTokens.count
        if !blocking { return "Blocking is off." }
        if a + c == 0 { return "No focus apps yet: every app is blocked during focus." }
        return "\(a) focus app\(a == 1 ? "" : "s")" + (c > 0 ? " and \(c) categor\(c == 1 ? "y" : "ies") (categories aren't used; pick apps)" : "")
    }

    private func turnBlocking(_ on: Bool) {
        screenTimeError = nil
        guard on else {
            ScreenTime.isOn = false
            let s = PorkStore.load()
            PorkCommands.apply(s)
            ScreenTime.scheduleNight(s.settings) // stops the late-night block
            return
        }
        Task {
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                ScreenTime.isOn = true
                let s = PorkStore.load()
                PorkCommands.apply(s)
                ScreenTime.scheduleNight(s.settings)
            } catch {
                blocking = false
                screenTimeError = "Screen Time wasn't allowed: \(error.localizedDescription)"
            }
        }
    }
    #endif
}

struct ShortcutHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("iPhone apps can't see when you pick up the phone or which app you open, and can't open other apps by themselves. Shortcuts automations do that for Pork. Make these 4, once. For each: open **Shortcuts** → **Automation** tab → **+** (or **New Automation**).")

                    Text("1. When you open a distraction app").font(.headline)
                    step(1, "Choose **App** → **Choose** → select your distraction apps (Instagram, YouTube, TikTok, Safari, games…). Not your focus apps. Tap **Done**.")
                    step(2, "Keep **Is Opened**, choose **Run Immediately**, turn off **Notify When Run**, tap **Next** → **New Blank Automation**.")
                    step(3, "**Add Action** → search **Pork: distraction app opened** → add it.")
                    step(4, "Add **If** under it (“If Pork: distraction app opened is true”). Inside the If, add **Show Pork's check-in**. Tap **Done**.")

                    Text("2. When you open a focus app").font(.headline)
                    step(1, "**App** → select Outlook, WeChat, Kindle, Gmail, Google Tasks, Google Calendar, Calendar, Reminders, Handshake, Slack, Canvas, Claude, Gemini, ChatGPT → **Done**.")
                    step(2, "**Is Opened**, **Run Immediately**, **Notify When Run** off → **Next** → **New Blank Automation**.")
                    step(3, "**Add Action** → **Pork: focus app opened** → **Done**.")

                    Text("3. 12:00 am: Outlook").font(.headline)
                    step(1, "Choose **Time of Day** → **12:00 AM**, **Daily**, **Run Immediately** → **Next** → **New Blank Automation**.")
                    step(2, "**Add Action** → **Pork: to-dos left?** → tap **App to open** and type Outlook.")
                    step(3, "Add **If** (“is true”), and inside it **Open App** → choose **Outlook**. Tap **Done**.")

                    Text("4. 6:00 pm: WeChat").font(.headline)
                    step(1, "Same as 3, with **6:00 PM** and **WeChat**.")

                    Text("At 12 am Pork checks yesterday's to-dos; at 6 pm today's. Apps only open while the phone is unlocked; otherwise you get Pork's reminder with the list.")
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .navigationTitle("Shortcuts for Pork")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
        }
    }

    private func step(_ n: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)").font(.headline).frame(width: 26, height: 26)
                .background(Color.porkFocus.opacity(0.18), in: Circle())
            Text(text)
        }
    }
}
