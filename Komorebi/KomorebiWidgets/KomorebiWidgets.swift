import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@main
struct KomorebiWidgetsBundle: WidgetBundle {
    var body: some Widget {
        GoToWidget()
        ReadingWidget()
        ListeningLiveActivity()
    }
}

// MARK: - Type (bundled fonts, listed in the widget's Info.plist)

private enum WFont {
    static func title(_ size: CGFloat) -> Font { .custom("Urbanist-Bold", size: size) }
    static func body(_ size: CGFloat) -> Font { .custom("Prompt-Regular", size: size) }
    static func medium(_ size: CGFloat) -> Font { .custom("Prompt-Medium", size: size) }
}

// MARK: - Timeline

struct PromptEntry: TimelineEntry {
    var date: Date
    var moment: PromptMoment
    var snapshot: WidgetSnapshot
}

/// Entries switch at the start and end of the person's wind-down time.
struct PromptProvider: TimelineProvider {
    func placeholder(in context: Context) -> PromptEntry {
        PromptEntry(date: Date(), moment: .standard, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (PromptEntry) -> Void) {
        let s = context.isPreview ? WidgetSnapshot.placeholder : WidgetSnapshot.load()
        completion(PromptEntry(date: Date(), moment: PromptMoment.at(Date(), snapshot: s), snapshot: s))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PromptEntry>) -> Void) {
        let s = WidgetSnapshot.load()
        let cal = Calendar.current
        let now = Date()
        var dates: [Date] = [now]
        let startOfToday = cal.startOfDay(for: now)
        for dayOffset in 0...1 {
            guard let day = cal.date(byAdding: .day, value: dayOffset, to: startOfToday) else { continue }
            for minutes in PromptMoment.boundaries(snapshot: s) {
                if let d = cal.date(byAdding: .minute, value: minutes, to: day), d > now { dates.append(d) }
            }
        }
        let entries = dates.sorted().prefix(12).map { PromptEntry(date: $0, moment: PromptMoment.at($0, snapshot: s), snapshot: s) }
        completion(Timeline(entries: entries, policy: .after(cal.date(byAdding: .hour, value: 12, to: now) ?? now)))
    }
}

// MARK: - What the widget says for each activity

private struct ActivityCopy {
    var label: String
    var subtitle: String
    var button: String
    var buttonIcon: String
    var art: String
    var coverID: String?

    init(_ s: WidgetSnapshot) {
        switch s.activityKey {
        case "garden":
            label = "Rake a sand garden"; subtitle = "One line at a time, right here."
            button = "Rake a line"; buttonIcon = "water.waves"; art = "WidgetGarden"; coverID = nil
        case "lantern":
            label = "Release a lantern"; subtitle = "Put one thought down for the night."
            button = "Begin"; buttonIcon = "flame"; art = "WidgetLantern"; coverID = nil
        default:
            let reading = s.storyID == s.activityKey && s.storyProgress > 0.02
            label = reading ? "Continue \(s.activityTitle)" : "Read \(s.activityTitle)"
            subtitle = reading && s.storyMinutesLeft > 0 ? "\(s.storyMinutesLeft) min left" : s.activityDetail
            button = reading ? "Continue" : "Read"; buttonIcon = "book"; art = "WidgetGarden"; coverID = s.activityKey
        }
    }
}

// MARK: - Go-to widget (Home Screen, StandBy, Lock Screen)

struct GoToWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "KomorebiGarden", provider: PromptProvider()) { entry in
            GoToWidgetView(entry: entry)
        }
        .configurationDisplayName("Your go-to")
        .description("Opens your go-to activity, or the one you chose in Settings. At your wind-down time it gently suggests it.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline])
        .contentMarginsDisabled()
    }
}

struct GoToWidgetView: View {
    var entry: PromptEntry
    @Environment(\.widgetFamily) private var family

    private var copy: ActivityCopy { ActivityCopy(entry.snapshot) }
    private var evening: Bool { entry.moment == .evening }
    private var link: URL { KomorebiLink.open(entry.snapshot.activityKey) }

    var body: some View {
        content
            .widgetURL(link)
            .containerBackground(for: .widget) { Palette.card }
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: copy.coverID != nil ? "book" : (entry.snapshot.activityKey == "lantern" ? "flame" : "leaf"))
                    .font(.system(size: 20, weight: .medium))
            }
            .accessibilityLabel(copy.label)
        case .accessoryInline:
            Label(evening ? "Tonight: \(entry.snapshot.activityTitle)" : copy.label, systemImage: "leaf")
        case .accessoryRectangular:
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.18))
                    Image(systemName: copy.coverID != nil ? "book" : (entry.snapshot.activityKey == "lantern" ? "flame" : "leaf"))
                        .font(.system(size: 16, weight: .medium))
                }
                .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text(evening ? "A little less to carry." : "komorebi").font(WFont.medium(12)).widgetAccentable().lineLimit(1)
                    Text(copy.label).font(WFont.title(15)).lineLimit(1)
                    Text(copy.subtitle).font(WFont.body(12)).lineLimit(1).opacity(0.8)
                }
            }
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
        case .systemMedium:
            HStack(spacing: 16) {
                art
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 6) {
                    if evening {
                        Text("TONIGHT").font(WFont.medium(11)).tracking(1.2).foregroundStyle(Palette.gold)
                    }
                    Text(copy.label).font(WFont.title(17)).foregroundStyle(Palette.text).lineLimit(2)
                    Text(evening ? "A little less to carry." : copy.subtitle).font(WFont.body(13)).foregroundStyle(Palette.text2).lineLimit(2)
                    Spacer(minLength: 4)
                    Label(copy.button, systemImage: copy.buttonIcon)
                        .font(WFont.medium(14))
                        .foregroundStyle(Palette.background)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(Capsule().fill(Palette.gold))
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding(16)
        default:
            ZStack(alignment: .bottomLeading) {
                art
                LinearGradient(colors: [.clear, Color(hex: 0x141726, opacity: 0.85)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 2) {
                    if evening { Text("TONIGHT").font(WFont.medium(10)).tracking(1.2).foregroundStyle(Palette.gold) }
                    Text(copy.label).font(WFont.medium(14)).foregroundStyle(Palette.text).lineLimit(2)
                }
                .padding(16)
            }
        }
    }

    @ViewBuilder private var art: some View {
        if let id = copy.coverID {
            ZStack {
                Palette.cardRaised
                Image("cover-\(id)").resizable().scaledToFit().padding(.vertical, 14)
            }
        } else {
            Image(copy.art).resizable().scaledToFill()
        }
    }
}

// MARK: - Reading widget

struct ReadingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "KomorebiReading", provider: PromptProvider()) { entry in
            ReadingWidgetView(entry: entry)
        }
        .configurationDisplayName("Your story")
        .description("Pick up the story you’re reading or listening to, right where you left off.")
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryCircular])
        .contentMarginsDisabled()
    }
}

struct ReadingWidgetView: View {
    var entry: PromptEntry
    @Environment(\.widgetFamily) private var family

    private var link: URL {
        if let id = entry.snapshot.storyID { return KomorebiLink.open(id) }
        return KomorebiLink.tonight
    }

    var body: some View {
        content
            .widgetURL(link)
            .containerBackground(for: .widget) {
                if family == .systemSmall { Palette.card } else { Color.clear }
            }
    }

    @ViewBuilder private var content: some View {
        let s = entry.snapshot
        switch family {
        case .accessoryCircular:
            // The gold ring from the Figma Lock Screen: progress through the story.
            Gauge(value: s.storyProgress) {
                Image(systemName: "book")
            } currentValueLabel: {
                Image(systemName: "book").font(.system(size: 16, weight: .medium))
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(Palette.gold)
            .accessibilityLabel(s.storyTitle.map { "\($0), \(Int(s.storyProgress * 100)) percent" } ?? "Komorebi stories")
        case .accessoryRectangular:
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.18))
                    Image(systemName: "book").font(.system(size: 14))
                }
                .frame(width: 28, height: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.storyTitle ?? "Start a story").font(WFont.title(15)).lineLimit(1).widgetAccentable()
                    Text(s.storyTitle == nil ? "Nine from across Asia" : "\(max(1, s.storyMinutesLeft)) min left").font(WFont.body(12)).opacity(0.8)
                    if s.storyTitle != nil { ProgressView(value: s.storyProgress).tint(Palette.gold) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            VStack(alignment: .leading, spacing: 6) {
                if let id = s.storyID {
                    Image("cover-\(id)").resizable().scaledToFit().frame(height: 62)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    Image(systemName: "book").font(.system(size: 26)).foregroundStyle(Palette.gold)
                }
                Spacer(minLength: 0)
                Text(s.storyTitle ?? "Start a story").font(WFont.title(15)).foregroundStyle(Palette.text).lineLimit(2)
                if s.storyTitle != nil {
                    Text("\(max(1, s.storyMinutesLeft)) min left").font(WFont.body(11)).foregroundStyle(Palette.text2)
                    ProgressView(value: s.storyProgress).tint(Palette.gold)
                } else {
                    Text("Tonight’s story is waiting").font(WFont.body(11)).foregroundStyle(Palette.text2)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Listening Live Activity (sleep timer), as in Figma

struct ListeningLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ListeningAttributes.self) { context in
            ListeningLockScreenView(context: context)
                .activityBackgroundTint(Palette.card)
                .activitySystemActionForegroundColor(Palette.gold)
                .widgetURL(KomorebiLink.listen(context.attributes.storyID))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("komorebi").font(WFont.medium(13)).foregroundStyle(Palette.gold).padding(.leading, 8)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Button(intent: ListeningActionIntent(action: "toggle")) {
                        Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill").foregroundStyle(Palette.text)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 8)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.title).font(WFont.title(16)).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        PlaybackBar(state: context.state)
                        if let end = context.state.sleepEndsAt, end > Date() {
                            HStack(spacing: 4) {
                                Text("Fades out in")
                                Text(timerInterval: Date()...end, countsDown: true).monospacedDigit()
                            }
                            .font(WFont.body(12)).foregroundStyle(Palette.gold)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)
                }
            } compactLeading: {
                Image(systemName: "headphones").foregroundStyle(Palette.gold)
            } compactTrailing: {
                if let end = context.state.sleepEndsAt, end > Date() {
                    Text(timerInterval: Date()...end, countsDown: true).monospacedDigit().frame(width: 44).foregroundStyle(Palette.gold)
                } else {
                    Image(systemName: context.state.isPlaying ? "waveform" : "pause.fill").foregroundStyle(Palette.gold)
                }
            } minimal: {
                Image(systemName: "moon").foregroundStyle(Palette.gold)
            }
            .widgetURL(KomorebiLink.listen(context.attributes.storyID))
        }
    }
}

/// A progress line with elapsed and total time; it keeps moving on its own while playing.
struct PlaybackBar: View {
    var state: ListeningAttributes.ContentState
    var body: some View {
        VStack(spacing: 4) {
            if state.isPlaying, let start = state.playStartedAt, state.duration > 0 {
                ProgressView(timerInterval: start...start.addingTimeInterval(state.duration), countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .tint(Palette.text)
                HStack {
                    Text(timerInterval: start...start.addingTimeInterval(state.duration), countsDown: false).monospacedDigit()
                    Spacer()
                    Text(state.duration.widgetTime)
                }
                .font(WFont.body(12)).foregroundStyle(Palette.text2)
            } else {
                ProgressView(value: state.duration > 0 ? min(1, state.elapsed / state.duration) : 0).tint(Palette.text)
                HStack {
                    Text(state.elapsed.widgetTime)
                    Spacer()
                    Text(state.duration.widgetTime)
                }
                .font(WFont.body(12)).foregroundStyle(Palette.text2)
            }
        }
    }
}

struct ListeningLockScreenView: View {
    var context: ActivityViewContext<ListeningAttributes>
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("komorebi").font(WFont.medium(15)).foregroundStyle(Palette.gold)
                Spacer()
                Image(systemName: "headphones").font(.system(size: 18)).foregroundStyle(Palette.gold)
            }
            HStack {
                Text(context.attributes.title).font(WFont.title(20)).foregroundStyle(Palette.text).lineLimit(1)
                Spacer()
                Button(intent: ListeningActionIntent(action: "toggle")) {
                    Image(systemName: context.state.isPlaying ? "pause" : "play.fill")
                        .font(.system(size: 20, weight: .semibold)).foregroundStyle(Palette.text)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(context.state.isPlaying ? "Pause" : "Play")
            }
            PlaybackBar(state: context.state)
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Sleep timer").font(WFont.body(13)).foregroundStyle(Palette.text2)
                    if let end = context.state.sleepEndsAt, end > Date() {
                        Text(timerInterval: Date()...end, countsDown: true)
                            .font(WFont.medium(16)).foregroundStyle(Palette.gold).monospacedDigit()
                    } else {
                        Text("Off").font(WFont.medium(16)).foregroundStyle(Palette.gold)
                    }
                }
                Spacer()
                Button(intent: ListeningActionIntent(action: "add15")) {
                    Text("+15 min").font(WFont.medium(14)).foregroundStyle(Palette.background)
                        .padding(.horizontal, 16).frame(height: 36)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Palette.gold))
                }
                .buttonStyle(.plain)
                Button(intent: ListeningActionIntent(action: "stop")) {
                    Text("Stop").font(WFont.medium(14)).foregroundStyle(Palette.text)
                        .padding(.horizontal, 16).frame(height: 36)
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.text, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
    }
}

private extension Double {
    var widgetTime: String {
        let s = Swift.max(0, Int(self.isFinite ? self : 0))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
