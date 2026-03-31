import Foundation

struct CaptureStatusResolver {
    static func resolve(
        source: LiveCaptureStatus.Source,
        isRunning: Bool,
        permission: CapturePermissionState,
        requestedHealth: CaptureHealthState,
        hasCapturedFrames: Bool,
        lastActivityAt: Date?,
        audioLevel: Float,
        detail: String?,
        didRetry: Bool,
        now: Date = .now
    ) -> LiveCaptureStatus {
        var health = requestedHealth

        if !isRunning {
            health = .idle
        } else if requestedHealth != .degraded {
            if hasCapturedFrames,
               let lastActivityAt,
               now.timeIntervalSince(lastActivityAt) <= 4 {
                health = .active
            } else {
                health = .starting
            }
        }

        return LiveCaptureStatus(
            source: source,
            permission: permission,
            health: health,
            hasCapturedFrames: hasCapturedFrames,
            lastActivityAt: lastActivityAt,
            audioLevel: audioLevel,
            detail: detail,
            didRetry: didRetry
        )
    }
}

struct AIStatusResolver {
    static func resolve(
        settings: AppSettings,
        knowledgeBase: KnowledgeBase?,
        sessionWarnings: [SessionWarning]
    ) -> AIStatusSnapshot {
        let providerName = settings.llmProvider.displayName
        let modelName = settings.activeLLMModel.trimmingCharacters(in: .whitespacesAndNewlines)
        let transcriptWarning = sessionWarnings.first?.message
        let kbReady = knowledgeBaseReady(settings: settings, knowledgeBase: knowledgeBase)

        if let configurationIssue = providerConfigurationIssue(for: settings) {
            return AIStatusSnapshot(
                state: .disabled,
                providerName: providerName,
                modelName: modelName,
                detail: configurationIssue,
                lastError: settings.lastAIError,
                lastSuccessAt: settings.lastAISuccessAt,
                knowledgeBaseReady: kbReady,
                transcriptWarning: transcriptWarning
            )
        }

        if let lastError = settings.lastAIError,
           !lastError.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return AIStatusSnapshot(
                state: .error,
                providerName: providerName,
                modelName: modelName,
                detail: "AI is configured, but the last provider call failed.",
                lastError: lastError,
                lastSuccessAt: settings.lastAISuccessAt,
                knowledgeBaseReady: kbReady,
                transcriptWarning: transcriptWarning
            )
        }

        if let transcriptWarning {
            return AIStatusSnapshot(
                state: .limited,
                providerName: providerName,
                modelName: modelName,
                detail: "Remote transcript capture is degraded, so transcript-dependent AI output may be incomplete.",
                lastError: nil,
                lastSuccessAt: settings.lastAISuccessAt,
                knowledgeBaseReady: kbReady,
                transcriptWarning: transcriptWarning
            )
        }

        if !kbReady {
            let detail: String
            if settings.kbFolderURL == nil {
                detail = "No knowledge base is configured. Local guidance still works, but KB-backed AI features are limited."
            } else {
                detail = "Knowledge base indexing is still in progress or unavailable."
            }

            return AIStatusSnapshot(
                state: .limited,
                providerName: providerName,
                modelName: modelName,
                detail: detail,
                lastError: nil,
                lastSuccessAt: settings.lastAISuccessAt,
                knowledgeBaseReady: false,
                transcriptWarning: nil
            )
        }

        return AIStatusSnapshot(
            state: .ready,
            providerName: providerName,
            modelName: modelName,
            detail: "\(providerName) is ready for suggestions, sidecast, and notes.",
            lastError: nil,
            lastSuccessAt: settings.lastAISuccessAt,
            knowledgeBaseReady: true,
            transcriptWarning: nil
        )
    }

    static func providerConfigurationIssue(for settings: AppSettings) -> String? {
        let modelName = settings.activeLLMModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !modelName.isEmpty else {
            return "AI is off because the selected \(settings.llmProvider.displayName) model is empty."
        }

        switch settings.llmProvider {
        case .openRouter:
            return settings.openRouterApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "AI is off because the OpenRouter API key is missing."
                : nil
        case .gemini:
            return settings.geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "AI is off because the Gemini API key is missing."
                : nil
        case .ollama, .mlx, .lmStudio, .openAICompatible:
            return settings.activeLLMChatCompletionsURL == nil
                ? "AI is off because the \(settings.llmProvider.displayName) endpoint is invalid."
                : nil
        }
    }

    static func knowledgeBaseReady(settings: AppSettings, knowledgeBase: KnowledgeBase?) -> Bool {
        guard settings.kbFolderURL != nil else { return false }
        return knowledgeBase?.isIndexed == true
    }
}
