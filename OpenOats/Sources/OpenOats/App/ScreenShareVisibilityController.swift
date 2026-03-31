import AppKit

@MainActor
final class ScreenShareVisibilityController {
    static let shared = ScreenShareVisibilityController()
    private var temporaryVisibilityEnabled = false

    private init() {}

    func sharingType(
        hideFromScreenShareByDefault: Bool,
        temporaryVisibilityEnabled: Bool
    ) -> NSWindow.SharingType {
        self.temporaryVisibilityEnabled = temporaryVisibilityEnabled
        return currentSharingType(hideFromScreenShareByDefault: hideFromScreenShareByDefault)
    }

    func currentSharingType(hideFromScreenShareByDefault: Bool) -> NSWindow.SharingType {
        if temporaryVisibilityEnabled {
            return .readOnly
        }
        return hideFromScreenShareByDefault ? .none : .readOnly
    }
}
