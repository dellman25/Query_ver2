import Foundation

/// Fetches the list of locally available models from an LM Studio instance.
enum LMStudioModelFetcher {
    struct ModelInfo: Decodable {
        let id: String
    }

    private struct ModelsResponse: Decodable {
        let data: [ModelInfo]
    }

    /// Returns model IDs sorted alphabetically, or an empty array on failure.
    static func fetchModels(baseURL: String, apiKey: String? = nil) async -> [String] {
        guard let url = modelsURL(from: baseURL) else {
            return []
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        if let apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              let modelNames = parseModelNames(from: data) else {
            return []
        }

        return modelNames
    }

    static func modelsURL(from rawBase: String) -> URL? {
        var base = rawBase.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard !base.isEmpty else { return nil }

        for suffix in ["/v1/models", "/v1"] {
            if base.hasSuffix(suffix) {
                base = String(base.dropLast(suffix.count))
            }
        }

        return URL(string: base + "/v1/models")
    }

    static func parseModelNames(from data: Data) -> [String]? {
        guard let decoded = try? JSONDecoder().decode(ModelsResponse.self, from: data) else {
            return nil
        }

        return Array(Set(decoded.data.map(\.id))).sorted()
    }
}
