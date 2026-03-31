import Foundation

enum CapturePermissionState: String, Codable, Sendable {
    case unknown
    case granted
    case denied
}

enum CaptureHealthState: String, Codable, Sendable {
    case idle
    case starting
    case active
    case degraded
}

struct LiveCaptureStatus: Sendable, Codable, Equatable {
    enum Source: String, Codable, Sendable {
        case microphone
        case systemAudio
    }

    let source: Source
    var permission: CapturePermissionState
    var health: CaptureHealthState
    var hasCapturedFrames: Bool
    var lastActivityAt: Date?
    var audioLevel: Float
    var detail: String?
    var didRetry: Bool

    static func idle(_ source: Source) -> LiveCaptureStatus {
        LiveCaptureStatus(
            source: source,
            permission: .unknown,
            health: .idle,
            hasCapturedFrames: false,
            lastActivityAt: nil,
            audioLevel: 0,
            detail: nil,
            didRetry: false
        )
    }
}

struct SessionWarning: Codable, Sendable, Equatable, Hashable, Identifiable {
    let code: String
    let message: String

    var id: String { code }
}

enum AIAvailabilityState: String, Codable, Sendable {
    case disabled
    case limited
    case ready
    case error
}

struct AIStatusSnapshot: Sendable, Codable, Equatable {
    var state: AIAvailabilityState
    var providerName: String
    var modelName: String
    var detail: String
    var lastError: String?
    var lastSuccessAt: Date?
    var knowledgeBaseReady: Bool
    var transcriptWarning: String?

    static let disabled = AIStatusSnapshot(
        state: .disabled,
        providerName: "AI",
        modelName: "",
        detail: "AI features are not configured yet.",
        lastError: nil,
        lastSuccessAt: nil,
        knowledgeBaseReady: false,
        transcriptWarning: nil
    )
}

enum AIConnectionTestState: Sendable, Equatable {
    case idle
    case testing
    case success(String)
    case failure(String)
}
