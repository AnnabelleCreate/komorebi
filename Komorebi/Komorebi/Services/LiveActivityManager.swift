import ActivityKit
import Foundation

/// Starts, updates and ends the "Listening" Live Activity on the Lock Screen and Dynamic Island.
/// Live Activities can only be started while Komorebi is open, which is when narration begins.
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private var activity: Activity<ListeningAttributes>?
    private init() {
        // Pick up an activity left over from a previous launch.
        activity = Activity<ListeningAttributes>.activities.first
    }

    var isAllowed: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    func startOrUpdate(story: Story?, state: ListeningAttributes.ContentState) {
        guard let story, isAllowed else { return }
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(60 * 60))
        if let activity, activity.attributes.storyID == story.id, activity.activityState == .active {
            Task { await activity.update(content) }
            return
        }
        end()
        let attributes = ListeningAttributes(storyID: story.id, title: story.title, author: story.author)
        do {
            activity = try Activity.request(attributes: attributes, content: content, pushType: nil)
        } catch {
            activity = nil // Live Activities turned off or limit reached; playback continues normally.
        }
    }

    func end() {
        let ending = Activity<ListeningAttributes>.activities
        activity = nil
        for item in ending {
            Task { await item.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
