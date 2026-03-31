import Foundation

actor LLMService {
    private let openAIClient = OpenRouterClient()
    private let geminiClient = GeminiClient()
    private let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
    }

    func complete(
        messages: [OpenRouterClient.Message],
        maxTokens: Int = 1024,
        modelOverride: String? = nil,
        feature: String
    ) async throws -> String {
        do {
            let backend = try await resolvedBackend(modelOverride: modelOverride)
            let response: String
            switch backend {
            case .openAICompatible(let apiKey, let model, let baseURL):
                response = try await openAIClient.complete(
                    apiKey: apiKey,
                    model: model,
                    messages: messages,
                    maxTokens: maxTokens,
                    baseURL: baseURL
                )
            case .gemini(let apiKey, let model):
                response = try await geminiClient.complete(
                    apiKey: apiKey,
                    model: model,
                    messages: messages,
                    maxTokens: maxTokens
                )
            }

            await markSuccess(feature: feature)
            return response
        } catch {
            await markFailure(error.localizedDescription)
            throw error
        }
    }

    func streamCompletion(
        messages: [OpenRouterClient.Message],
        maxTokens: Int = 1024,
        modelOverride: String? = nil,
        feature: String
    ) async -> AsyncThrowingStream<String, Error> {
        let backend: Backend
        do {
            backend = try await resolvedBackend(modelOverride: modelOverride)
        } catch {
            await markFailure(error.localizedDescription)
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: error)
            }
        }

        let upstream: AsyncThrowingStream<String, Error>
        switch backend {
        case .openAICompatible(let apiKey, let model, let baseURL):
            upstream = await openAIClient.streamCompletion(
                apiKey: apiKey,
                model: model,
                messages: messages,
                maxTokens: maxTokens,
                baseURL: baseURL
            )
        case .gemini(let apiKey, let model):
            upstream = await geminiClient.streamCompletion(
                apiKey: apiKey,
                model: model,
                messages: messages,
                maxTokens: maxTokens
            )
        }

        return AsyncThrowingStream { continuation in
            let task = Task { [weak self] in
                do {
                    for try await chunk in upstream {
                        continuation.yield(chunk)
                    }
                    if let self {
                        await self.markSuccess(feature: feature)
                    }
                    continuation.finish()
                } catch {
                    if let self {
                        await self.markFailure(error.localizedDescription)
                    }
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func listModelsForCurrentProvider() async throws -> [String] {
        let provider = await MainActor.run { settings.llmProvider }
        switch provider {
        case .gemini:
            let apiKey = try requiredAPIKey(
                await MainActor.run { settings.geminiApiKey },
                provider: provider
            )
            return try await geminiClient.listModels(apiKey: apiKey)
        default:
            return []
        }
    }

    func testConnection() async throws -> String {
        let messages: [OpenRouterClient.Message] = [
            .init(role: "user", content: "Reply with exactly OK.")
        ]
        let response = try await complete(
            messages: messages,
            maxTokens: 16,
            feature: "connection test"
        )
        let normalized = response.trimmingCharacters(in: .whitespacesAndNewlines)
        let provider = await MainActor.run { settings.llmProvider.displayName }
        return normalized.isEmpty ? "\(provider) responded." : "\(provider) responded: \(normalized)"
    }

    private func resolvedBackend(modelOverride: String?) async throws -> Backend {
        let provider = await MainActor.run { settings.llmProvider }
        let activeModel = await MainActor.run { settings.activeLLMModel }
        let chosenModel = (modelOverride ?? activeModel).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !chosenModel.isEmpty else {
            throw LLMServiceError.notConfigured("\(provider.displayName) model is missing.")
        }

        switch provider {
        case .gemini:
            return .gemini(
                apiKey: try requiredAPIKey(
                    await MainActor.run { settings.geminiApiKey },
                    provider: provider
                ),
                model: chosenModel
            )
        case .openRouter:
            return .openAICompatible(
                apiKey: try requiredAPIKey(
                    await MainActor.run { settings.openRouterApiKey },
                    provider: provider
                ),
                model: chosenModel,
                baseURL: nil
            )
        case .ollama, .mlx, .lmStudio, .openAICompatible:
            let baseURL = await MainActor.run { settings.activeLLMChatCompletionsURL }
            guard let baseURL else {
                throw LLMServiceError.notConfigured("Invalid \(provider.displayName) endpoint.")
            }
            return .openAICompatible(
                apiKey: await MainActor.run { settings.activeLLMApiKey },
                model: chosenModel,
                baseURL: baseURL
            )
        }
    }

    private func markSuccess(feature: String) async {
        await MainActor.run {
            settings.noteAISuccess(feature: feature)
            if case .testing = settings.aiConnectionTestState {
                settings.setAIConnectionTestState(.success("Connection OK"))
            }
        }
    }

    private func markFailure(_ message: String) async {
        await MainActor.run {
            settings.noteAIError(message)
            if case .testing = settings.aiConnectionTestState {
                settings.setAIConnectionTestState(.failure(message))
            }
        }
    }
}

private extension LLMService {
    enum Backend {
        case openAICompatible(apiKey: String?, model: String, baseURL: URL?)
        case gemini(apiKey: String, model: String)
    }

    func requiredAPIKey(_ rawValue: String, provider: LLMProvider) throws -> String {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            throw LLMServiceError.notConfigured("\(provider.displayName) API key is missing.")
        }
        return value
    }
}

enum LLMServiceError: Error, LocalizedError {
    case notConfigured(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured(let message):
            return message
        }
    }
}
