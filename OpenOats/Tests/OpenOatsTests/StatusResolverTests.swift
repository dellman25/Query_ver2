import XCTest
@testable import OpenOatsKit

@MainActor
final class StatusResolverTests: XCTestCase {
    private func makeStore() -> AppSettings {
        let suiteName = "com.query.tests.status.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        let storage = AppSettingsStorage(
            defaults: defaults,
            secretStore: .ephemeral,
            defaultNotesDirectory: URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("StatusResolverTests"),
            runMigrations: false
        )
        return AppSettings(storage: storage)
    }

    func testCaptureStatusResolverReturnsIdleWhenNotRunning() {
        let status = CaptureStatusResolver.resolve(
            source: .microphone,
            isRunning: false,
            permission: .granted,
            requestedHealth: .starting,
            hasCapturedFrames: true,
            lastActivityAt: .now,
            audioLevel: 0.6,
            detail: nil,
            didRetry: false
        )

        XCTAssertEqual(status.health, .idle)
    }

    func testCaptureStatusResolverReturnsActiveForRecentFrames() {
        let status = CaptureStatusResolver.resolve(
            source: .systemAudio,
            isRunning: true,
            permission: .granted,
            requestedHealth: .starting,
            hasCapturedFrames: true,
            lastActivityAt: .now,
            audioLevel: 0.2,
            detail: nil,
            didRetry: true
        )

        XCTAssertEqual(status.health, .active)
        XCTAssertTrue(status.didRetry)
    }

    func testCaptureStatusResolverPreservesDegradedState() {
        let status = CaptureStatusResolver.resolve(
            source: .systemAudio,
            isRunning: true,
            permission: .denied,
            requestedHealth: .degraded,
            hasCapturedFrames: false,
            lastActivityAt: nil,
            audioLevel: 0,
            detail: "System audio capture unavailable.",
            didRetry: true
        )

        XCTAssertEqual(status.health, .degraded)
        XCTAssertEqual(status.permission, .denied)
    }

    func testAIStatusResolverReturnsDisabledWhenGeminiKeyMissing() {
        let settings = makeStore()
        settings.llmProvider = .gemini
        settings.geminiModel = "gemini-2.5-flash"

        let status = AIStatusResolver.resolve(settings: settings, knowledgeBase: nil, sessionWarnings: [])

        XCTAssertEqual(status.state, .disabled)
        XCTAssertEqual(status.providerName, "Gemini")
    }

    func testAIStatusResolverReturnsErrorForProviderFailure() {
        let settings = makeStore()
        settings.llmProvider = .openRouter
        settings.openRouterApiKey = "key"
        settings.selectedModel = "google/gemini-3-flash-preview"
        settings.noteAIError("Upstream timeout")

        let status = AIStatusResolver.resolve(settings: settings, knowledgeBase: nil, sessionWarnings: [])

        XCTAssertEqual(status.state, .error)
        XCTAssertEqual(status.lastError, "Upstream timeout")
    }

    func testAIStatusResolverReturnsLimitedForTranscriptWarning() {
        let settings = makeStore()
        settings.llmProvider = .openRouter
        settings.openRouterApiKey = "key"
        settings.selectedModel = "google/gemini-3-flash-preview"

        let status = AIStatusResolver.resolve(
            settings: settings,
            knowledgeBase: nil,
            sessionWarnings: [
                SessionWarning(
                    code: "remote-transcription-unavailable",
                    message: "Remote transcription was unavailable for part of this meeting."
                )
            ]
        )

        XCTAssertEqual(status.state, .limited)
        XCTAssertEqual(status.transcriptWarning, "Remote transcription was unavailable for part of this meeting.")
    }
}
