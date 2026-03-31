import SwiftUI

struct SessionSetupView: View {
    @Binding var sessionTitle: String
    @Binding var interviewSetup: InterviewSetup
    let controllerState: LiveSessionState
    let onStartInterview: () -> Void
    let onConfirmDownload: () -> Void
    let onOpenPastInterviews: () -> Void

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case title, processArea, role, objective
    }

    private var canStart: Bool {
        !sessionTitle.trimmingCharacters(in: .whitespaces).isEmpty
        && !interviewSetup.processArea.trimmingCharacters(in: .whitespaces).isEmpty
        && !interviewSetup.intervieweeRole.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if let lastSession = controllerState.lastEndedSession, lastSession.utteranceCount > 0 {
                sessionEndedBanner(lastSession)
                Divider()
            }

            batchProgressBanner

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    heroSection
                    formSection
                }
                .padding(32)
            }

            Spacer(minLength: 0)

            Divider()

            startSection
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Query")
                .font(.system(size: 14, weight: .semibold))

            Spacer()

            if !controllerState.kbIndexingProgress.isEmpty {
                Text(controllerState.kbIndexingProgress)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Button(action: onOpenPastInterviews) {
                HStack(spacing: 4) {
                    Image(systemName: "note.text")
                        .font(.system(size: 11))
                    Text("Past Interviews")
                        .font(.system(size: 11))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("View past interview sessions")
            .accessibilityIdentifier("app.pastMeetingsButton")

            SettingsLink {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
                    .padding(4)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Settings")
            .accessibilityIdentifier("app.settingsButton")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("New Interview Session")
                .font(.system(size: 20, weight: .semibold))

            Text("Set up your interview context so Query can guide your questioning and capture structured requirements.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Form

    private var formSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            formField(
                label: "Session Title",
                placeholder: "e.g. Trade Settlement Walkthrough\u{2026}",
                text: $sessionTitle,
                field: .title,
                isRequired: true
            )

            formField(
                label: "Process Area",
                placeholder: "e.g. Trade Reconciliation, Client Onboarding\u{2026}",
                text: $interviewSetup.processArea,
                field: .processArea,
                isRequired: true
            )

            formField(
                label: "Interviewee Role",
                placeholder: "e.g. Settlement Analyst, Ops Team Lead\u{2026}",
                text: $interviewSetup.intervieweeRole,
                field: .role,
                isRequired: true
            )

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 4) {
                    Text("Discovery Objective")
                        .font(.system(size: 12, weight: .medium))
                    Text("optional")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }

                TextEditor(text: $interviewSetup.objective)
                    .font(.system(size: 13))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: 56, maxHeight: 80)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.primary.opacity(0.03))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    .focused($focusedField, equals: .objective)
                    .accessibilityLabel("Discovery Objective")
            }
        }
    }

    private func formField(
        label: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        isRequired: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                if isRequired {
                    Text("*")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.red.opacity(0.7))
                }
            }

            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(0.03))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(
                            focusedField == field
                                ? Color.accentColor.opacity(0.5)
                                : Color.primary.opacity(0.08),
                            lineWidth: 1
                        )
                )
                .focused($focusedField, equals: field)
                .onSubmit { advanceFocus(from: field) }
                .accessibilityLabel(label)
        }
    }

    private func advanceFocus(from field: Field) {
        switch field {
        case .title: focusedField = .processArea
        case .processArea: focusedField = .role
        case .role: focusedField = .objective
        case .objective: focusedField = nil
        }
    }

    // MARK: - Start Section

    private var startSection: some View {
        VStack(spacing: 0) {
            if let error = controllerState.errorMessage {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
            }

            if controllerState.needsDownload {
                VStack(spacing: 6) {
                    Text(controllerState.transcriptionPrompt)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Download Now") {
                        onConfirmDownload()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            if let status = controllerState.statusMessage, status != "Ready" {
                statusBanner(status)
            }

            HStack {
                Spacer()
                Button(action: onStartInterview) {
                    HStack(spacing: 6) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 12))
                        Text("Start Interview")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 9)
                    .background(canStart ? Color.accentColor : Color.accentColor.opacity(0.4))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!canStart)
                .help(canStart ? "Start recording the interview" : "Fill in required fields to start")
                .accessibilityIdentifier("app.startInterview")
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private func statusBanner(_ status: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if controllerState.downloadProgress == nil {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(status)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            if let progress = controllerState.downloadProgress {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                if let detail = controllerState.downloadDetail {
                    HStack(spacing: 8) {
                        if let sizeText = detail.sizeText { Text(sizeText) }
                        if let speedText = detail.speedText { Text(speedText) }
                        if let etaText = detail.etaText {
                            Spacer()
                            Text(etaText)
                        }
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    // MARK: - Session Ended Banner

    private func sessionEndedBanner(_ lastSession: SessionIndex) -> some View {
        HStack {
            Text("Session ended \u{00B7} \(lastSession.utteranceCount) utterances")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("app.sessionEndedBanner")
            Spacer()
            Button(action: onOpenPastInterviews) {
                Label("View Notes", systemImage: "doc.text")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityIdentifier("app.viewNotesButton")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: - Batch Progress

    @ViewBuilder
    private var batchProgressBanner: some View {
        if case .transcribing(let progress) = controllerState.batchStatus {
            HStack(spacing: 8) {
                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(.linear)
                    .frame(maxWidth: .infinity)
                Text(controllerState.batchIsImporting
                     ? "Importing interview recording\u{2026} \(Int(progress * 100))%"
                     : "Enhancing transcript\u{2026} \(Int(progress * 100))%")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            Divider()
        } else if case .loading = controllerState.batchStatus {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(controllerState.batchIsImporting ? "Preparing to import\u{2026}" : "Loading batch model\u{2026}")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            Divider()
        } else if case .completed = controllerState.batchStatus {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 12))
                Text(controllerState.batchIsImporting ? "Interview recording imported" : "Transcript enhanced")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            Divider()
        }
    }
}
