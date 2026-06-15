import ActivityKit
import Foundation

@available(iOS 16.1, *)
@MainActor
final class VegasLiveActivityManager {
    static let shared = VegasLiveActivityManager()
    private var activity: Activity<RoundLiveActivityAttributes>?

    func start(attributes: RoundLiveActivityAttributes, initialState: RoundLiveActivityAttributes.ContentState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // Reattach to any lingering activity from a previous session
        if activity == nil, let existing = Activity<RoundLiveActivityAttributes>.activities.first {
            activity = existing
        }
        if activity != nil {
            Task { await update(state: initialState) }
            return
        }
        do {
            let content = ActivityContent(state: initialState, staleDate: nil)
            activity = try Activity.request(attributes: attributes, content: content)
        } catch {
            // Silently fail because Live Activities may not be available on all devices.
        }
    }

    func update(state: RoundLiveActivityAttributes.ContentState) async {
        guard let activity else { return }
        let content = ActivityContent(state: state, staleDate: nil)
        await activity.update(content)
    }

    func end(finalState: RoundLiveActivityAttributes.ContentState) async {
        guard let activity else { return }
        let content = ActivityContent(state: finalState, staleDate: nil)
        await activity.end(content, dismissalPolicy: .default)
        self.activity = nil
    }
}
