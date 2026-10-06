// Settings: clock, blocking (Screen Time), focus sites, "Pork says hi",
// treat jar.

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
                }

                #if !LITE
                Section {
                    Toggle("Block distractions during focus", isOn: $blocking)
                        .onChange(of: blocking) { _, on in turnBlocking(on) }
                    Button("Choose focus apps…") { pickApps = true }
                        .disabled(!blocking)
                    Text(appsSummary).font(.footnote).foregroundStyle(.secondary)
                    if let screenTimeError {
                        Text(screenTimeError).font(.footnote).foregroundStyle(.red)
                    }
                } header: {
                    Text("Blocking (Screen Time)")
                } footer: {
                    Text("During focus every app except your focus apps shows Pork's screen. After the focus goal, that screen has a “Start my break” button. When the break is over it comes back with “Let Pork out”. Pick Safari plus ChatGPT, Claude, Gemini, Libby, Books… and Messages, Mail and Phone if you want them.")
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
                    Text("During focus, Safari only opens these sites. “mit.edu” also covers ocw.mit.edu and other subdomains. Lines like youtube.com/@mitocw can't be checked per channel on iPhone, so they're skipped while blocking; add youtube.com if you need YouTube.")
                }

                Section {
                    Toggle("Show Pork when I pick up my phone", isOn: $st.hiEnabled)
                    Picker("Album in Photos", selection: $st.hiAlbum) {
                        ForEach(albumChoices, id: \.self) { Text($0).tag($0) }
                    }
                    Stepper("Watch Pork for \(st.hiSeconds) s", value: $st.hiSeconds, in: 15...600, step: 15)
                    Stepper(st.hiGraceMin == 0 ? "Ask every time" : "Then leave me alone for \(st.hiGraceMin) min",
                            value: $st.hiGraceMin, in: 0...240, step: 5)
                    Toggle("Videos without sound", isOn: $st.hiMuted)
                    Button("Try it now") {
                        save()
                        dismiss()
                        model.showHi = true
                    }
                    Button("How to turn it on (Shortcuts)") { showShortcutHelp = true }
                } header: {
                    Text("Pork says hi")
                } footer: {
                    Text("When you open an app (not Phone, Messages or Mail) and the clock isn't running, Pork's photos and videos play first. Then you choose whether to continue.")
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
            .onChange(of: pickApps) { _, open in
                guard !open else { return }
                ScreenTime.focusApps = focusApps
                PorkCommands.apply(PorkStore.load())
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
            PorkCommands.apply(PorkStore.load())
            return
        }
        Task {
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                ScreenTime.isOn = true
                PorkCommands.apply(PorkStore.load())
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
                    Text("iPhone apps can't see when you unlock your phone, so a Shortcuts automation opens Pork whenever you open another app.")
                    step(1, "Open the **Shortcuts** app → **Automation** tab → **+** (or **New Automation**).")
                    step(2, "Choose **App**. Tap **Choose**, select every app you want Pork to greet you in. Don't select Phone, Messages, Mail or Puppy Pomodoro. Tap **Done**.")
                    step(3, "Keep **Is Opened** checked. Choose **Run Immediately** and turn off **Notify When Run**. Tap **Next**.")
                    step(4, "Tap **New Blank Automation**. Tap **Add Action**, search for **Should Pork say hi**, and add it.")
                    step(5, "Search for **If** and add it under the first action. It should read “If **Should Pork say hi** is **true**”. (Tap the condition to pick “is true” if needed.)")
                    step(6, "Search for **Say hi to Pork** and drag it inside the If (between If and Otherwise). Tap **Done**.")
                    Text("That's it. When the clock isn't running, opening one of those apps shows Pork first. After you choose “Yes, continue”, Pork leaves you alone for the time you set; swipe right along the bottom edge of the screen to go back to your app.")
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .navigationTitle("Pork says hi")
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
