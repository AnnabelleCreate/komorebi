import SwiftUI

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(PromptScheduler.self) private var prompts
    @State private var confirmErase = false

    var body: some View {
        @Bindable var store = store
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // MARK: Notification preferences (one schedule drives the widget and the notification)
                Text("Notification Preferences").font(KFont.heading(20)).foregroundStyle(Palette.text).accessibilityAddTraits(.isHeader)
                Text("Choose your wind-down time. During it, the Komorebi widget suggests your go-to activity, and you can get one quiet notification. Never streaks.")
                    .font(KFont.body(14)).foregroundStyle(Palette.text2)
                if prompts.permission == .denied && store.state.evening.isOn && store.state.evening.sendsNotification {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "bell.slash").foregroundStyle(Palette.warm)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Notifications are off for Komorebi in iPhone Settings. The widget still follows your schedule.")
                                .font(KFont.body(14)).foregroundStyle(Palette.text)
                            Button("Open iPhone Settings") { prompts.openSystemSettings() }.buttonStyle(GhostButtonStyle())
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Palette.warm.opacity(0.12)))
                }
                PromptEditor(schedule: $store.state.evening)

                // MARK: Widget
                Text("Widget").font(KFont.heading(20)).foregroundStyle(Palette.text).padding(.top, 10).accessibilityAddTraits(.isHeader)
                WidgetPicker()

                // MARK: Accessibility
                Text("Accessibility").font(KFont.heading(20)).foregroundStyle(Palette.text).padding(.top, 10).accessibilityAddTraits(.isHeader)
                Text("Applies to every activity: stories, the sand garden and the lantern.").font(KFont.body(14)).foregroundStyle(Palette.text2)

                SectionLabel(text: "Seeing")
                SettingsGroup {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Text size").font(KFont.body(16)).foregroundStyle(Palette.text)
                        PillPicker(options: TextSizeChoice.allCases.map { ($0, $0.label) }, selection: $store.state.textSize, label: "Text size")
                    }
                    .padding(16)
                    RowDivider()
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Activity light").font(KFont.body(16)).foregroundStyle(Palette.text)
                        Text("Dark sand for night, or lighter sand").font(KFont.body(14)).foregroundStyle(Palette.text2)
                        PillPicker(options: GardenLight.allCases.map { ($0, $0.label) }, selection: $store.state.settings.gardenLight, label: "Activity light")
                    }
                    .padding(16)
                    RowDivider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Warm screen").font(KFont.body(16)).foregroundStyle(Palette.text)
                        Text("An amber tint everywhere outside the reader, which has its own").font(KFont.body(14)).foregroundStyle(Palette.text2)
                        Slider(value: $store.state.settings.warmScreen, in: 0...1).tint(Palette.gold).accessibilityLabel("Warm screen")
                    }
                    .padding(16)
                    RowDivider()
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Reduce motion").font(KFont.body(16)).foregroundStyle(Palette.text)
                        Text("Soft fades instead of sliding, zooming or spinning").font(KFont.body(14)).foregroundStyle(Palette.text2)
                        PillPicker(options: MotionPreference.allCases.map { ($0, $0.label) }, selection: $store.state.settings.reduceMotion, label: "Reduce motion")
                    }
                    .padding(16)
                }

                SectionLabel(text: "Touch").padding(.top, 6)
                SettingsGroup {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Steady touch").font(KFont.body(16)).foregroundStyle(Palette.text)
                        Text("Smooths shaky or tremoring hands wherever you draw, trace or rake. Steadiest is on by default, so nobody has to ask for it.")
                            .font(KFont.body(14)).foregroundStyle(Palette.text2)
                        PillPicker(options: SteadyLevel.allCases.map { ($0, $0.label) }, selection: $store.state.settings.steady, label: "Steady touch")
                    }
                    .padding(16)
                    RowDivider()
                    SettingRow(title: "One-tap raking", detail: "Buttons in the sand garden that rake lines and rings for you. Helpful with VoiceOver or Switch Control.") {
                        Toggle("", isOn: $store.state.settings.oneTapRaking).labelsHidden().tint(Palette.gold).accessibilityLabel("One-tap raking")
                    }
                    RowDivider()
                    SettingRow(title: "Tap instead of hold", detail: "Any press-and-hold, like releasing a lantern, becomes a single tap") {
                        Toggle("", isOn: $store.state.settings.tapInsteadOfHold).labelsHidden().tint(Palette.gold).accessibilityLabel("Tap instead of hold")
                    }
                }

                SectionLabel(text: "Hearing & feel").padding(.top, 6)
                SettingsGroup {
                    SettingRow(title: "Gentle sounds", detail: "Soft taps, page turns, chimes") {
                        Toggle("", isOn: $store.state.settings.gentleSounds).labelsHidden().tint(Palette.gold).accessibilityLabel("Gentle sounds")
                    }
                    RowDivider()
                    SettingRow(title: "Ambience", detail: "Water, wind and sand in activities") {
                        Toggle("", isOn: $store.state.settings.ambience).labelsHidden().tint(Palette.gold).accessibilityLabel("Ambience")
                    }
                    RowDivider()
                    SettingRow(title: "Volume", detail: nil) {
                        Slider(value: $store.state.settings.volume, in: 0...1) { editing in
                            if !editing { SoundEngine.shared.play(.tap) }
                        }
                        .tint(Palette.gold).frame(width: 150).accessibilityLabel("Volume")
                    }
                    RowDivider()
                    SettingRow(title: "Haptics", detail: "Light taps on supported phones") {
                        Toggle("", isOn: $store.state.settings.haptics).labelsHidden().tint(Palette.gold).accessibilityLabel("Haptics")
                    }
                }

                // MARK: Kept lines
                Text("Lines you kept").font(KFont.heading(20)).foregroundStyle(Palette.text).padding(.top, 10).accessibilityAddTraits(.isHeader)
                SettingsGroup {
                    if store.state.keptLines.isEmpty {
                        SettingRow(title: "Nothing kept yet", detail: "When you finish a story, you can keep a line you liked.") { EmptyView() }
                    } else {
                        ForEach(Array(store.state.keptLines.enumerated()), id: \.element.id) { index, line in
                            if index > 0 { RowDivider() }
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("“\(line.text)”").font(KFont.reading(16, serif: true)).foregroundStyle(Palette.text)
                                    if let story = StoryLibrary.shared.story(line.storyID) {
                                        Text("\(story.title) · \(story.author)").font(KFont.body(14)).foregroundStyle(Palette.text3)
                                    }
                                }
                                Spacer()
                                Button {
                                    store.state.keptLines.removeAll { $0.id == line.id }
                                } label: {
                                    Image(systemName: "xmark").foregroundStyle(Palette.text3).frame(width: 44, height: 44)
                                }
                                .accessibilityLabel("Let go of this line")
                            }
                            .padding(16)
                        }
                    }
                }

                // MARK: More
                Text("More").font(KFont.heading(20)).foregroundStyle(Palette.text).padding(.top, 10).accessibilityAddTraits(.isHeader)
                SettingsGroup {
                    NavigationLink { OrdersView() } label: {
                        SettingRow(title: "Your orders", detail: "Track, skip or cancel") { Image(systemName: "chevron.right").foregroundStyle(Palette.text2) }
                    }
                    RowDivider()
                    NavigationLink { AboutView() } label: {
                        SettingRow(title: "About & credits", detail: "Stories, narration, privacy") { Image(systemName: "chevron.right").foregroundStyle(Palette.text2) }
                    }
                    RowDivider()
                    Button { confirmErase = true } label: {
                        SettingRow(title: "Erase everything", detail: "Favorites, progress, orders and settings on this phone") {
                            Image(systemName: "trash").foregroundStyle(Palette.warm)
                        }
                    }
                }
                .buttonStyle(.plain)

                Text("Lantern thoughts are never saved. No streaks, no history.")
                    .font(KFont.body(14)).foregroundStyle(Palette.text3).frame(maxWidth: .infinity).padding(.top, 8)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .kScreen()
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog("Erase everything Komorebi saved?", isPresented: $confirmErase, titleVisibility: .visible) {
            Button("Erase everything", role: .destructive) { store.eraseEverything() }
            Button("Keep my things", role: .cancel) {}
        } message: {
            Text("This can’t be undone. Your garden, favorites, reading places, kept lines, orders and settings will be removed from this phone.")
        }
        .onAppear { prompts.refreshAuthorizationStatus() }
    }

}

/// The wind-down schedule, laid out like the Figma Settings screen: Scheduled, days, and a time window.
struct PromptEditor: View {
    @Binding var schedule: PromptSchedule
    @Environment(PromptScheduler.self) private var prompts

    private let days = [(1, "S", "Sunday"), (2, "M", "Monday"), (3, "T", "Tuesday"), (4, "W", "Wednesday"), (5, "T", "Thursday"), (6, "F", "Friday"), (7, "S", "Saturday")]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsGroup {
                SettingRow(title: "Scheduled", detail: nil) {
                    Toggle("", isOn: Binding(get: { schedule.isOn }, set: { on in
                        schedule.isOn = on
                        if on && schedule.sendsNotification && prompts.permission == .notDetermined { prompts.requestPermission() }
                    }))
                    .labelsHidden().tint(Palette.gold).accessibilityLabel("Scheduled")
                }
            }
            Group {
                SettingsGroup {
                    dayRow(.every, "Every Day")
                    RowDivider()
                    dayRow(.custom, "Customize Days")
                    if schedule.days == .custom {
                        HStack(spacing: 4) {
                            ForEach(days.indices, id: \.self) { index in
                                let d = days[index]
                                let on = schedule.customDays.contains(d.0)
                                Button {
                                    if on { schedule.customDays.removeAll { $0 == d.0 } } else { schedule.customDays.append(d.0) }
                                    Haptics.shared.selection()
                                } label: {
                                    Text(d.1).font(KFont.medium(14))
                                        .frame(width: 44, height: 44)
                                        .foregroundStyle(on ? Palette.background : Palette.text2)
                                        .background(Circle().fill(on ? Palette.gold : .clear))
                                        .overlay(Circle().strokeBorder(on ? .clear : Palette.outline))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(d.2)
                                .accessibilityAddTraits(on ? .isSelected : [])
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(12)
                    }
                }
                SettingsGroup {
                    timeRow("From", minutes: $schedule.startMinutes)
                    RowDivider()
                    timeRow("Until", minutes: $schedule.endMinutes)
                }
                SettingsGroup {
                    SettingRow(title: "Quiet notification", detail: "One notification with no sound when your wind-down time starts") {
                        Toggle("", isOn: Binding(get: { schedule.sendsNotification }, set: { on in
                            schedule.style = on ? .notification : .widget
                            if on && prompts.permission == .notDetermined { prompts.requestPermission() }
                        }))
                        .labelsHidden().tint(Palette.gold).accessibilityLabel("Quiet notification")
                    }
                    if schedule.sendsNotification {
                        RowDivider()
                        Button {
                            if prompts.permission == .allowed {
                                prompts.sendPreview(night: false)
                            } else {
                                prompts.requestPermission { granted in if granted { prompts.sendPreview(night: false) } }
                            }
                        } label: {
                            SettingRow(title: "Send a preview", detail: "Arrives in 5 seconds") {
                                Image(systemName: "paperplane").foregroundStyle(Palette.gold)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .disabled(!schedule.isOn)
            .opacity(schedule.isOn ? 1 : 0.45)
        }
    }

    private func dayRow(_ value: PromptDays, _ label: String) -> some View {
        Button {
            schedule.days = value
            Haptics.shared.selection()
        } label: {
            HStack {
                Text(label).font(KFont.body(16)).foregroundStyle(Palette.text)
                Spacer()
                if schedule.days == value { Image(systemName: "checkmark").foregroundStyle(Palette.text) }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(schedule.days == value ? .isSelected : [])
    }

    private func timeRow(_ label: String, minutes: Binding<Int>) -> some View {
        DatePicker(selection: Binding(get: {
            Calendar.current.date(bySettingHour: minutes.wrappedValue / 60, minute: minutes.wrappedValue % 60, second: 0, of: Date()) ?? Date()
        }, set: { date in
            let p = Calendar.current.dateComponents([.hour, .minute], from: date)
            minutes.wrappedValue = (p.hour ?? 0) * 60 + (p.minute ?? 0)
        }), displayedComponents: .hourAndMinute) {
            Text(label).font(KFont.body(16)).foregroundStyle(Palette.text)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
    }
}

/// Which favorite the widget opens.
struct WidgetPicker: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        let favorites = store.state.favorites.compactMap(ActivityItem.from(key:))
        let goTo = store.state.goTo.flatMap(ActivityItem.from(key:))
        VStack(alignment: .leading, spacing: 10) {
            Text("Tap the widget on your Home Screen or Lock Screen to go straight to this activity.")
                .font(KFont.body(14)).foregroundStyle(Palette.text2)
            SettingsGroup {
                pickRow(key: nil, title: "My go-to", detail: goTo?.title ?? "Choose one in Profile → Favorites")
                ForEach(favorites) { item in
                    RowDivider()
                    pickRow(key: item.id, title: item.title, detail: item.shortLine)
                }
            }
            if favorites.isEmpty {
                Text("Add favorites with the heart on any activity or story to choose them here.")
                    .font(KFont.body(14)).foregroundStyle(Palette.text3)
            }
        }
    }

    private func pickRow(key: String?, title: String, detail: String) -> some View {
        let on = store.state.widgetActivity == key
        return Button {
            store.state.widgetActivity = key
            Haptics.shared.selection()
        } label: {
            SettingRow(title: title, detail: detail) {
                if on { Image(systemName: "checkmark").foregroundStyle(Palette.gold) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Komorebi").font(KFont.title(28)).foregroundStyle(Palette.text)
                Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.9") beta · AIxD Project 3, Carnegie Mellon University")
                    .font(KFont.body(14)).foregroundStyle(Palette.text2)
                group("Stories", "Nine public-domain works from Project Gutenberg: Lafcadio Hearn’s Kwaidan (1904), Yei Theodora Ozaki’s Japanese Fairy Tales (1908), and Rabindranath Tagore’s Gitanjali (1912), The Gardener (1913) and The Hungry Stones and Other Stories (1916).")
                group("Narration", "Read by LibriVox volunteers. LibriVox recordings are in the public domain.")
                group("Your privacy", "Everything Komorebi remembers stays on this phone: favorites, reading places, kept lines, your garden, orders and settings. Lantern thoughts are never stored. The microphone is only used during Lantern release to notice one breath, and nothing is recorded.")
                group("Sounds", "Interface sounds and ambient loops were made for Komorebi.")
            }
            .padding(16)
        }
        .kScreen()
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func group(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(KFont.heading(20)).foregroundStyle(Palette.text)
            Text(text).font(KFont.body(14)).foregroundStyle(Palette.text2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .kCard(radius: 14)
    }
}
