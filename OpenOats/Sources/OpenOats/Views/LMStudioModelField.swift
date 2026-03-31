import SwiftUI

/// A text field with a dropdown button that lists models available on the configured LM Studio instance.
struct LMStudioModelField: View {
    @Binding var modelName: String
    let baseURL: String
    let apiKey: String
    let placeholder: String

    @State private var availableModels: [String] = []
    @State private var isLoading = false

    var body: some View {
        HStack(spacing: 4) {
            TextField("Model", text: $modelName, prompt: Text(placeholder))
                .font(.system(size: 12, design: .monospaced))

            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 16, height: 16)
            } else {
                Menu {
                    if emptyStateMessage == "No models found" {
                        Button("No models found at /v1/models") {}
                            .disabled(true)
                    } else {
                        Button(emptyStateMessage) {}
                            .disabled(true)
                    }

                    if !availableModels.isEmpty {
                        ForEach(availableModels, id: \.self) { model in
                            Button(model) {
                                modelName = model
                            }
                        }
                    }
                    Divider()
                    Button("Refresh Models") {
                        Task { await fetchModels() }
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                        .frame(width: 16, height: 16)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Choose from the models currently loaded in LM Studio")
            }
        }
        .task(id: fetchConfigurationKey) {
            await fetchModels()
        }
    }

    private var fetchConfigurationKey: String {
        "\(baseURL)|\(apiKey)"
    }

    private var emptyStateMessage: String {
        if baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Enter an LM Studio URL first"
        }

        return "No models found"
    }

    private func fetchModels() async {
        guard !baseURL.trimmingCharacters(in: .whitespaces).isEmpty else {
            availableModels = []
            return
        }
        isLoading = true
        availableModels = await LMStudioModelFetcher.fetchModels(baseURL: baseURL, apiKey: apiKey)
        isLoading = false
    }
}
