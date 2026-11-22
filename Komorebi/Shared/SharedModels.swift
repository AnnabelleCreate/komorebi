import Foundation
import SwiftUI

/// Values shared by the app and the widget extension.
enum KomorebiShared {
    /// App Group used to pass a small snapshot to the widgets.
    /// If the App Group isn't set up yet (for example on a free signing team),
    /// both sides fall back to standard defaults and widgets show their default content.
    static let appGroupID = "group.edu.cmu.aixd.komorebi"
    static let urlScheme = "komorebi"
    static let snapshotKey = "widget.snapshot.v1"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }
}

/// Deep links used by notifications, widgets and Live Activities.
enum KomorebiLink {
    static let garden = URL(string: "komorebi://garden")!
    static let lantern = URL(string: "komorebi://lantern")!
    static let tonight = URL(string: "komorebi://tonight")!
    static let kits = URL(string: "komorebi://kits")!
    static func read(_ id: String) -> URL { URL(string: "komorebi://read/\(id)")! }
    static func listen(_ id: String) -> URL { URL(string: "komorebi://listen/\(id)")! }
    /// Opens any activity by key: "garden", "lantern" or a story id.
    static func open(_ key: String) -> URL { URL(string: "komorebi://open/\(key)")! }
}

/// A small, privacy-safe summary the app writes for its widgets.
/// It never contains anything the person typed.
struct WidgetSnapshot: Codable, Equatable {
    var storyID: String?
    var storyTitle: String?
    var storyAuthor: String?
    var storyProgress: Double
    var eveningOn: Bool
    var eveningAsWidget: Bool
    var eveningMinutes: Int
    var eveningWeekdays: [Int]
    var nightOn: Bool
    var nightAsWidget: Bool
    var nightStartMinutes: Int
    var nightEndMinutes: Int
    var nightWeekdays: [Int]
    /// End of the wind-down window (minutes after midnight).
    var eveningEndMinutes: Int = 22 * 60
    /// The activity the widget opens ("garden", "lantern" or a story id), with its display name.
    var activityKey: String = "garden"
    var activityTitle: String = "Sand garden"
    var activityDetail: String = "Ritual · as long as you like"
    /// Minutes left in the story being read or listened to.
    var storyMinutesLeft: Int = 0

    static let placeholder = WidgetSnapshot(
        storyID: "yuki-onna", storyTitle: "Yuki-Onna", storyAuthor: "Lafcadio Hearn", storyProgress: 0.3,
        eveningOn: true, eveningAsWidget: true, eveningMinutes: 20 * 60, eveningWeekdays: Array(1...7),
        nightOn: false, nightAsWidget: false, nightStartMinutes: 60, nightEndMinutes: 5 * 60, nightWeekdays: Array(1...7),
        eveningEndMinutes: 22 * 60, activityKey: "garden", activityTitle: "Sand garden",
        activityDetail: "Ritual · as long as you like", storyMinutesLeft: 5
    )

    init(storyID: String?, storyTitle: String?, storyAuthor: String?, storyProgress: Double,
         eveningOn: Bool, eveningAsWidget: Bool, eveningMinutes: Int, eveningWeekdays: [Int],
         nightOn: Bool, nightAsWidget: Bool, nightStartMinutes: Int, nightEndMinutes: Int, nightWeekdays: [Int],
         eveningEndMinutes: Int = 22 * 60, activityKey: String = "garden", activityTitle: String = "Sand garden",
         activityDetail: String = "Ritual · as long as you like", storyMinutesLeft: Int = 0) {
        self.storyID = storyID; self.storyTitle = storyTitle; self.storyAuthor = storyAuthor; self.storyProgress = storyProgress
        self.eveningOn = eveningOn; self.eveningAsWidget = eveningAsWidget; self.eveningMinutes = eveningMinutes; self.eveningWeekdays = eveningWeekdays
        self.nightOn = nightOn; self.nightAsWidget = nightAsWidget; self.nightStartMinutes = nightStartMinutes
        self.nightEndMinutes = nightEndMinutes; self.nightWeekdays = nightWeekdays
        self.eveningEndMinutes = eveningEndMinutes; self.activityKey = activityKey; self.activityTitle = activityTitle
        self.activityDetail = activityDetail; self.storyMinutesLeft = storyMinutesLeft
    }

    private enum CodingKeys: String, CodingKey {
        case storyID, storyTitle, storyAuthor, storyProgress, eveningOn, eveningAsWidget, eveningMinutes, eveningWeekdays
        case nightOn, nightAsWidget, nightStartMinutes, nightEndMinutes, nightWeekdays
        case eveningEndMinutes, activityKey, activityTitle, activityDetail, storyMinutesLeft
    }

    /// Tolerant decoding so an older snapshot never breaks the widget.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let p = WidgetSnapshot.placeholder
        storyID = try? c.decode(String.self, forKey: .storyID)
        storyTitle = try? c.decode(String.self, forKey: .storyTitle)
        storyAuthor = try? c.decode(String.self, forKey: .storyAuthor)
        storyProgress = (try? c.decode(Double.self, forKey: .storyProgress)) ?? 0
        eveningOn = (try? c.decode(Bool.self, forKey: .eveningOn)) ?? p.eveningOn
        eveningAsWidget = (try? c.decode(Bool.self, forKey: .eveningAsWidget)) ?? p.eveningAsWidget
        eveningMinutes = (try? c.decode(Int.self, forKey: .eveningMinutes)) ?? p.eveningMinutes
        eveningWeekdays = (try? c.decode([Int].self, forKey: .eveningWeekdays)) ?? p.eveningWeekdays
        nightOn = (try? c.decode(Bool.self, forKey: .nightOn)) ?? false
        nightAsWidget = (try? c.decode(Bool.self, forKey: .nightAsWidget)) ?? false
        nightStartMinutes = (try? c.decode(Int.self, forKey: .nightStartMinutes)) ?? p.nightStartMinutes
        nightEndMinutes = (try? c.decode(Int.self, forKey: .nightEndMinutes)) ?? p.nightEndMinutes
        nightWeekdays = (try? c.decode([Int].self, forKey: .nightWeekdays)) ?? p.nightWeekdays
        eveningEndMinutes = (try? c.decode(Int.self, forKey: .eveningEndMinutes)) ?? p.eveningEndMinutes
        activityKey = (try? c.decode(String.self, forKey: .activityKey)) ?? p.activityKey
        activityTitle = (try? c.decode(String.self, forKey: .activityTitle)) ?? p.activityTitle
        activityDetail = (try? c.decode(String.self, forKey: .activityDetail)) ?? p.activityDetail
        storyMinutesLeft = (try? c.decode(Int.self, forKey: .storyMinutesLeft)) ?? 0
    }

    static func load() -> WidgetSnapshot {
        guard let data = KomorebiShared.defaults.data(forKey: KomorebiShared.snapshotKey),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return .placeholder
        }
        return snapshot
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        KomorebiShared.defaults.set(data, forKey: KomorebiShared.snapshotKey)
    }
}

/// What a widget should suggest at a given moment.
enum PromptMoment: String {
    case standard, evening, night

    /// Works out the moment for `date` from the person's prompt settings.
    static func at(_ date: Date, snapshot s: WidgetSnapshot, calendar: Calendar = .current) -> PromptMoment {
        let parts = calendar.dateComponents([.hour, .minute, .weekday], from: date)
        let minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        let weekday = parts.weekday ?? 1

        if s.nightOn && s.nightAsWidget {
            let start = s.nightStartMinutes, end = s.nightEndMinutes
            let inWindow = start <= end ? (minutes >= start && minutes < end) : (minutes >= start || minutes < end)
            // A night window that starts after midnight belongs to the night that began the day before.
            let nightDay = (start <= end || minutes >= start) ? weekday : (weekday == 1 ? 7 : weekday - 1)
            if inWindow && s.nightWeekdays.contains(nightDay) { return .night }
        }
        if s.eveningOn && s.eveningAsWidget {
            let start = s.eveningMinutes, end = s.eveningEndMinutes
            let crosses = end <= start
            let inWindow = crosses ? (minutes >= start || minutes < end) : (minutes >= start && minutes < end)
            // After midnight, the window belongs to the evening that started the day before.
            let day = (crosses && minutes < end) ? (weekday == 1 ? 7 : weekday - 1) : weekday
            if inWindow && s.eveningWeekdays.contains(day) { return .evening }
        }
        return .standard
    }

    /// Minute marks where the moment can change, used to build widget timelines.
    static func boundaries(snapshot s: WidgetSnapshot) -> [Int] {
        var marks = [0, s.eveningMinutes, s.eveningEndMinutes, s.nightStartMinutes, s.nightEndMinutes]
        marks = Array(Set(marks)).sorted()
        return marks
    }
}

/// Komorebi design tokens (V2 design system).
enum Palette {
    static let background = Color(hex: 0x141726)
    static let card = Color(hex: 0x1C2139)
    static let cardRaised = Color(hex: 0x262C4A)
    static let text = Color(hex: 0xFBEDD6)
    static let text2 = Color(hex: 0xAEB8CA)
    static let text3 = Color(hex: 0x8A91A5)
    static let gold = Color(hex: 0xF6CE87)
    static let warm = Color(hex: 0xE28E78)
    static let outline = Color(hex: 0x3A3E5A)
    static let outlineStrong = Color(hex: 0x7A8199)
    static let surface = Color(hex: 0xE8F3FE)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }

    /// Parses "#RRGGBB". Falls back to the card color.
    init(hexString: String) {
        let clean = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        if let value = UInt32(clean, radix: 16), clean.count == 6 {
            self.init(hex: value)
        } else {
            self.init(hex: 0x1C2139)
        }
    }
}
