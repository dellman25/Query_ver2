import Foundation

actor GeminiClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func complete(
        apiKey: String,
        model: String,
        messages: [OpenRouterClient.Message],
        maxTokens: Int = 1024
    ) async throws -> String {
        let request = try makeURLRequest(
            apiKey: apiKey,
            model: model,
            messages: messages,
            maxTokens: maxTokens,
            stream: false
        )
        let (data, response) = try await session.data(for: request)
        try validate(response: response)

        let decoded = try JSONDecoder().decode(GenerateContentResponse.self, from: data)
        return decoded.flattenedText
    }

    func streamCompletion(
        apiKey: String,
        model: String,
        messages: [OpenRouterClient.Message],
        maxTokens: Int = 1024
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try makeURLRequest(
                        apiKey: apiKey,
                        model: model,
                        messages: messages,
                        maxTokens: maxTokens,
                        stream: true
                    )
                    let (bytes, response) = try await session.bytes(for: request)
                    try validate(response: response)

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        guard !payload.isEmpty else { continue }
                        guard let data = payload.data(using: .utf8) else { continue }
                        let decoded = try JSONDecoder().decode(GenerateContentResponse.self, from: data)
                        let text = decoded.flattenedText
                        if !text.isEmpty {
                            continuation.yield(text)
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func listModels(apiKey: String) async throws -> [String] {
        var request = URLRequest(url: Self.modelsURL)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        let (data, response) = try await session.data(for: request)
        try validate(response: response)

        let decoded = try JSONDecoder().decode(ModelListResponse.self, from: data)
        return decoded.models
            .filter { $0.supportedActions?.contains("generateContent") == true }
            .map { Self.userFacingModelName(from: $0.name) }
            .sorted()
    }

    private func makeURLRequest(
        apiKey: String,
        model: String,
        messages: [OpenRouterClient.Message],
        maxTokens: Int,
        stream: Bool
    ) throws -> URLRequest {
        let endpoint = Self.endpointURL(for: model, stream: stream)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONEncoder().encode(
            GenerateContentRequest(messages: messages, maxTokens: maxTokens)
        )
        return request
    }

    private func validate(response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw GeminiError.httpError(statusCode)
        }
    }

    private static let baseURL = URL(string: "https://generativelanguage.googleapis.com/v1beta")!
    private static let modelsURL = baseURL.appendingPathComponent("models")

    private static func endpointURL(for model: String, stream: Bool) -> URL {
        let normalizedModel = normalizedModelName(model)
        let path = "models/\(normalizedModel):\(stream ? "streamGenerateContent" : "generateContent")"
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if stream {
            components.queryItems = [URLQueryItem(name: "alt", value: "sse")]
        }
        return components.url!
    }

    private static func normalizedModelName(_ rawModel: String) -> String {
        let trimmed = rawModel.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("models/") {
            return String(trimmed.dropFirst("models/".count))
        }
        return trimmed
    }

    private static func userFacingModelName(from rawModel: String) -> String {
        if rawModel.hasPrefix("models/") {
            return String(rawModel.dropFirst("models/".count))
        }
        return rawModel
    }
}

private struct GenerateContentRequest: Encodable {
    let systemInstruction: GeminiInstruction?
    let contents: [GeminiContent]
    let generationConfig: GeminiGenerationConfig

    init(messages: [OpenRouterClient.Message], maxTokens: Int) {
        let systemText = messages
            .filter { $0.role == "system" }
            .map(\.content)
            .joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.systemInstruction = systemText.isEmpty ? nil : GeminiInstruction(
            parts: [.init(text: systemText)]
        )

        let mappedContents = messages.compactMap { message -> GeminiContent? in
            guard message.role != "system" else { return nil }
            let role = message.role == "assistant" ? "model" : "user"
            return GeminiContent(role: role, parts: [.init(text: message.content)])
        }
        self.contents = mappedContents.isEmpty
            ? [GeminiContent(role: "user", parts: [.init(text: "Reply with OK.")])]
            : mappedContents
        self.generationConfig = GeminiGenerationConfig(maxOutputTokens: maxTokens)
    }
}

private struct GeminiInstruction: Encodable {
    let parts: [GeminiPart]
}

private struct GeminiContent: Codable {
    let role: String?
    let parts: [GeminiPart]?
}

private struct GeminiPart: Codable {
    let text: String?
}

private struct GeminiGenerationConfig: Encodable {
    let maxOutputTokens: Int
}

private struct GenerateContentResponse: Decodable {
    let candidates: [GeminiCandidate]?

    var flattenedText: String {
        candidates?
            .compactMap(\.content?.parts)
            .flatMap { $0 }
            .compactMap(\.text)
            .joined() ?? ""
    }
}

private struct GeminiCandidate: Decodable {
    let content: GeminiContent?
}

private struct ModelListResponse: Decodable {
    let models: [GeminiModel]
}

private struct GeminiModel: Decodable {
    let name: String
    let supportedActions: [String]?
}

enum GeminiError: Error, LocalizedError {
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .httpError(let code):
            return "Gemini API error (HTTP \(code))"
        }
    }
}
