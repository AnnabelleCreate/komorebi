import Foundation
#if canImport(ActivityKit)
import ActivityKit
import AppIntents

/// Live Activity shown while a story is being narrated (with an optional sleep timer).
struct ListeningAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var isPlaying: Bool
        /// When the sleep timer will fade the story out, if one is set.
        var sleepEndsAt: Date?
        /// Seconds into the story when this state was sent.
        var elapsed: Double
        var duration: Double
        /// When playback (re)started, so the Live Activity's progress can move on its own.
        var playStartedAt: Date?
    }

    var storyID: String
    var title: String
    var author: String
}

/// Buttons on the Live Activity (+15 min, Stop, play/pause). They run inside the app.
enum ListeningControl {
    /// Set by the app at launch. Actions: "toggle", "add15", "stop".
    static var handler: ((String) -> Void)?
}

struct ListeningActionIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Control Komorebi narration"
    static let isDiscoverable = false

    @Parameter(title: "Action") var action: String

    init() { action = "toggle" }
    init(action: String) { self.action = action }

    func perform() async throws -> some IntentResult {
        let action = self.action
        await MainActor.run { ListeningControl.handler?(action) }
        return .result()
    }
}
#endif
