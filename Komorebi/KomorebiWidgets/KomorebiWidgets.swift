import ActivityKit
import SwiftUI
import WidgetKit

@main
struct KomorebiWidgetsBundle: WidgetBundle {
    var body: some Widget {
        GardenWidget()
        ReadingWidget()
        ListeningLiveActivity()
    }
}

// MARK: - Timeline

struct PromptEntry: TimelineEntry {
    var date: Date
    var moment: PromptMoment
    var snapshot: WidgetSnapshot
}

/// Builds a day of entries that switch at the evening and night prompt times.
struct PromptProvider: TimelineProvider {
    func placeholder(in context: Context) -> PromptEntry {
        PromptEntry(date: Date(), moment: .standard, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (PromptEntry) -> Void) {
        let s = WidgetSnapshot.load()
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

// MARK: - Sand garden widget (Home Screen, Lock Screen, StandBy)

struct GardenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "KomorebiGarden", provider: PromptProvider()) { entry in
            GardenWidgetView(entry: entry)
        }
        .configurationDisplayName("Sand garden")
        .description("Rake a sand garden. At the times you choose, it gently suggests tonight’s activity.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

struct GardenWidgetView: View {
    var entry: PromptEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var headline: String {
        switch entry.moment {
        case .night: return "Still awake?"
        case .evening: return "A little less to carry"
        case .standard: return "Rake a sand garden"
        }
    }

    private var detail: String {
        switch entry.moment {
        case .night: return "Rake slowly. Drift back."
        case .evening: return "Tonight: Lantern release"
        case .standard: return "Slow lines, three stones"
        }
    }

    private var link: URL { entry.moment == .evening ? KomorebiLink.lantern : KomorebiLink.garden }

    var body: some View {
        content
            .widgetURL(link)
            .containerBackground(for: .widget) {
                if family == .systemSmall || family == .systemMedium {
                    ZStack {
                        Image(family == .systemMedium ? "WidgetGardenWide" : "WidgetGarden").resizable().scaledToFill()
                        LinearGradient(colors: [.clear, Color(hex: 0x141726, opacity: 0.85)], startPoint: .center, endPoint: .bottom)
                    }
                } else {
                    Color.clear
                }
            }
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: entry.moment == .evening ? "flame" : (entry.moment == .night ? "moon.zzz" : "circle.circle"))
                    .font(.system(size: 20, weight: .medium))
            }
            .accessibilityLabel(headline)
        case .accessoryInline:
            Label(headline, systemImage: entry.moment == .evening ? "flame" : "moon")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Label("komorebi", systemImage: entry.moment == .evening ? "flame" : "moon")
                    .font(.system(size: 12, weight: .semibold))
                    .widgetAccentable()
                Text(headline).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                Text(detail).font(.system(size: 13)).lineLimit(1).opacity(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            VStack(alignment: .leading, spacing: 2) {
                Spacer()
                Text(headline).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(Palette.text)
                Text(detail).font(.system(size: 12)).foregroundStyle(Palette.text.opacity(0.8))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
        .description("Pick up the story you’re reading, right where you left off.")
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryCircular])
    }
}

struct ReadingWidgetView: View {
    var entry: PromptEntry
    @Environment(\.widgetFamily) private var family

    private var link: URL {
        if let id = entry.snapshot.storyID { return KomorebiLink.read(id) }
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
            Gauge(value: s.storyProgress) { Image(systemName: "book") } currentValueLabel: {
                Text(s.storyTitle == nil ? "Read" : "\(Int(s.storyProgress * 100))%")
            }
            .gaugeStyle(.accessoryCircularCapacity)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Label("komorebi", systemImage: "book").font(.system(size: 12, weight: .semibold)).widgetAccentable()
                Text(s.storyTitle ?? "Start a story").font(.system(size: 15, weight: .semibold)).lineLimit(1)
                if s.storyTitle != nil {
                    ProgressView(value: s.storyProgress)
                } else {
                    Text("Nine from across Asia").font(.system(size: 13)).opacity(0.8)
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
                Text(s.storyTitle ?? "Start a story").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(Palette.text).lineLimit(2)
                if s.storyTitle != nil {
                    ProgressView(value: s.storyProgress).tint(Palette.gold)
                } else {
                    Text("Tonight’s story is waiting").font(.system(size: 11)).foregroundStyle(Palette.text2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Listening Live Activity

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
                    Image(systemName: context.state.isPlaying ? "waveform" : "pause.fill").foregroundStyle(Palette.gold).padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let end = context.state.sleepEndsAt, end > Date() {
                        Text(timerInterval: Date()...end, countsDown: true).monospacedDigit().foregroundStyle(Palette.gold).frame(width: 56)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 1) {
                        Text(context.attributes.title).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                        Text(context.attributes.author).font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.sleepEndsAt == nil ? "Narrated by a LibriVox volunteer" : "The voice will fade out gently")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "book").foregroundStyle(Palette.gold)
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

struct ListeningLockScreenView: View {
    var context: ActivityViewContext<ListeningAttributes>
    var body: some View {
        HStack(spacing: 14) {
            Image("cover-\(context.attributes.storyID)")
                .resizable().scaledToFit().frame(width: 44, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            VStack(alignment: .leading, spacing: 3) {
                Text(context.attributes.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.text).lineLimit(1)
                Text(context.attributes.author).font(.system(size: 13)).foregroundStyle(Palette.text2)
                if let end = context.state.sleepEndsAt, end > Date() {
                    HStack(spacing: 4) {
                        Image(systemName: "moon.zzz")
                        Text("Fades out in")
                        Text(timerInterval: Date()...end, countsDown: true).monospacedDigit()
                    }
                    .font(.system(size: 12)).foregroundStyle(Palette.gold)
                } else {
                    Text(context.state.isPlaying ? "Playing" : "Paused").font(.system(size: 12)).foregroundStyle(Palette.text3)
                }
            }
            Spacer()
            Image(systemName: context.state.isPlaying ? "waveform" : "pause.fill").font(.system(size: 20)).foregroundStyle(Palette.gold)
        }
        .padding(16)
    }
}
