import Foundation

// MARK: - Settings

enum TextSizeChoice: String, Codable, CaseIterable, Identifiable {
    case standard, large, larger
    var id: String { rawValue }
    var label: String {
        switch self {
        case .standard: return "Standard"
        case .large: return "Large"
        case .larger: return "Larger"
        }
    }
}

enum GardenLight: String, Codable, CaseIterable, Identifiable {
    case night, bright, matchPhone
    var id: String { rawValue }
    var label: String {
        switch self {
        case .night: return "Night"
        case .bright: return "Bright"
        case .matchPhone: return "Match phone"
        }
    }
}

enum SteadyLevel: String, Codable, CaseIterable, Identifiable {
    case off, gentle, strong, steadiest
    var id: String { rawValue }
    var label: String {
        switch self {
        case .off: return "Off"
        case .gentle: return "Gentle"
        case .strong: return "Strong"
        case .steadiest: return "Steadiest"
        }
    }
}

enum MotionPreference: String, Codable, CaseIterable, Identifiable {
    case followPhone, on, off
    var id: String { rawValue }
    var label: String {
        switch self {
        case .followPhone: return "Match phone"
        case .on: return "On"
        case .off: return "Off"
        }
    }
}

struct AppSettings: Codable, Equatable {
    var gentleSounds = true
    var ambience = true
    var volume: Double = 0.7
    var haptics = true
    var gardenLight: GardenLight = .night
    var warmScreen: Double = 0
    var reduceMotion: MotionPreference = .followPhone
    var steady: SteadyLevel = .steadiest
    var oneTapRaking = false
    var tapInsteadOfHold = false

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        gentleSounds = (try? c.decode(Bool.self, forKey: .gentleSounds)) ?? d.gentleSounds
        ambience = (try? c.decode(Bool.self, forKey: .ambience)) ?? d.ambience
        volume = (try? c.decode(Double.self, forKey: .volume)) ?? d.volume
        haptics = (try? c.decode(Bool.self, forKey: .haptics)) ?? d.haptics
        gardenLight = (try? c.decode(GardenLight.self, forKey: .gardenLight)) ?? d.gardenLight
        warmScreen = (try? c.decode(Double.self, forKey: .warmScreen)) ?? d.warmScreen
        reduceMotion = (try? c.decode(MotionPreference.self, forKey: .reduceMotion)) ?? d.reduceMotion
        steady = (try? c.decode(SteadyLevel.self, forKey: .steady)) ?? d.steady
        oneTapRaking = (try? c.decode(Bool.self, forKey: .oneTapRaking)) ?? d.oneTapRaking
        tapInsteadOfHold = (try? c.decode(Bool.self, forKey: .tapInsteadOfHold)) ?? d.tapInsteadOfHold
    }
}

struct ReadingComfort: Codable, Equatable {
    static let sizes: [Double] = [15, 17, 18.5, 20, 22]
    static let sizeNames = ["Small", "Medium", "Comfortable", "Large", "Largest"]
    var sizeIndex = 2
    var serif = true
    var warmth: Double = 0.35
    var dimSlowly = false

    var pointSize: Double { ReadingComfort.sizes[max(0, min(ReadingComfort.sizes.count - 1, sizeIndex))] }

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sizeIndex = (try? c.decode(Int.self, forKey: .sizeIndex)) ?? 2
        serif = (try? c.decode(Bool.self, forKey: .serif)) ?? true
        warmth = (try? c.decode(Double.self, forKey: .warmth)) ?? 0.35
        dimSlowly = (try? c.decode(Bool.self, forKey: .dimSlowly)) ?? false
    }
}

// MARK: - Prompts

enum PromptStyle: String, Codable, CaseIterable, Identifiable {
    case notification, widget
    var id: String { rawValue }
    var label: String { self == .notification ? "Notification" : "Lock Screen widget" }
}

enum PromptDays: String, Codable { case every, custom }

struct PromptSchedule: Codable, Equatable {
    var isOn: Bool
    var style: PromptStyle
    var days: PromptDays
    /// Calendar weekdays, 1 = Sunday … 7 = Saturday.
    var customDays: [Int]
    /// Minutes after midnight.
    var startMinutes: Int
    /// Minutes after midnight; only used by the night prompt's window.
    var endMinutes: Int

    static let eveningDefault = PromptSchedule(isOn: true, style: .notification, days: .every, customDays: [2, 3, 4, 5, 6], startMinutes: 20 * 60, endMinutes: 22 * 60)
    static let nightDefault = PromptSchedule(isOn: true, style: .widget, days: .every, customDays: Array(1...7), startMinutes: 60, endMinutes: 5 * 60)

    var activeWeekdays: [Int] { days == .every ? Array(1...7) : customDays.sorted() }
}

// MARK: - Orders

enum KitPlan: String, Codable { case once, monthly }

struct ShippingAddress: Codable, Equatable {
    var name = ""
    var street = ""
    var apartment = ""
    var city = ""
    var state = ""
    var zip = ""

    var oneLine: String {
        var parts = [street]
        if !apartment.trimmingCharacters(in: .whitespaces).isEmpty { parts.append(apartment) }
        parts.append("\(city), \(state) \(zip)")
        return parts.joined(separator: ", ")
    }
}

struct KitOrder: Codable, Identifiable, Equatable {
    var id = UUID()
    var number: String
    var placedAt: Date
    var plan: KitPlan
    var isActive: Bool
    var skipNextBox = false
    var address: ShippingAddress
    var paymentSummary: String
    var totalCents: Int

    var arrivesFrom: Date { Calendar.current.date(byAdding: .day, value: 3, to: placedAt) ?? placedAt }
    var arrivesBy: Date { Calendar.current.date(byAdding: .day, value: 7, to: placedAt) ?? placedAt }

    /// Next monthly box ships one month after the last shipment (skips move it a month further).
    var nextShipDate: Date? {
        guard plan == .monthly, isActive else { return nil }
        let cal = Calendar.current
        var next = cal.date(byAdding: .month, value: 1, to: placedAt) ?? placedAt
        while next < Date() { next = cal.date(byAdding: .month, value: 1, to: next) ?? next.addingTimeInterval(30 * 86400) }
        if skipNextBox { next = cal.date(byAdding: .month, value: 1, to: next) ?? next }
        return next
    }

    enum Stage: Int, CaseIterable { case ordered, packed, onItsWay, delivered
        var label: String {
            switch self {
            case .ordered: return "Ordered"
            case .packed: return "Packed"
            case .onItsWay: return "On its way"
            case .delivered: return "On your nightstand"
            }
        }
    }

    var stage: Stage {
        let days = Date().timeIntervalSince(placedAt) / 86400
        if days >= 7 { return .delivered }
        if days >= 3 { return .onItsWay }
        if days >= 1 { return .packed }
        return .ordered
    }
}

// MARK: - Reading

struct ReadingProgress: Codable, Equatable {
    var blockIndex: Int
    var fraction: Double
    var finished: Bool
    var updatedAt: Date
}

struct KeptLine: Codable, Identifiable, Equatable {
    var id = UUID()
    var storyID: String
    var text: String
    var keptAt: Date
}

// MARK: - App state

struct AppState: Codable, Equatable {
    var schemaVersion = 1
    var onboarded = false
    var name = ""
    var textSize: TextSizeChoice = .standard
    var settings = AppSettings()
    var comfort = ReadingComfort()
    var evening = PromptSchedule.eveningDefault
    var night = PromptSchedule.nightDefault
    var favorites: [String] = ["garden", "lantern", "yuki-onna"]
    var orders: [KitOrder] = []
    var savedAddress: ShippingAddress?
    var progress: [String: ReadingProgress] = [:]
    var audioPositions: [String: Double] = [:]
    var lastStoryID: String?
    var keptLines: [KeptLine] = []

    init() {}

    /// Decodes field by field so an older or partly damaged save never wipes everything.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppState()
        schemaVersion = (try? c.decode(Int.self, forKey: .schemaVersion)) ?? d.schemaVersion
        onboarded = (try? c.decode(Bool.self, forKey: .onboarded)) ?? d.onboarded
        name = (try? c.decode(String.self, forKey: .name)) ?? d.name
        textSize = (try? c.decode(TextSizeChoice.self, forKey: .textSize)) ?? d.textSize
        settings = (try? c.decode(AppSettings.self, forKey: .settings)) ?? d.settings
        comfort = (try? c.decode(ReadingComfort.self, forKey: .comfort)) ?? d.comfort
        evening = (try? c.decode(PromptSchedule.self, forKey: .evening)) ?? d.evening
        night = (try? c.decode(PromptSchedule.self, forKey: .night)) ?? d.night
        favorites = (try? c.decode([String].self, forKey: .favorites)) ?? d.favorites
        orders = (try? c.decode([KitOrder].self, forKey: .orders)) ?? d.orders
        savedAddress = try? c.decode(ShippingAddress.self, forKey: .savedAddress)
        progress = (try? c.decode([String: ReadingProgress].self, forKey: .progress)) ?? d.progress
        audioPositions = (try? c.decode([String: Double].self, forKey: .audioPositions)) ?? d.audioPositions
        lastStoryID = try? c.decode(String.self, forKey: .lastStoryID)
        keptLines = (try? c.decode([KeptLine].self, forKey: .keptLines)) ?? d.keptLines
    }
}
