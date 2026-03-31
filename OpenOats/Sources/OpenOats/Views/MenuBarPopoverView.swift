import SwiftUI

struct MenuBarPopoverView: View {
    let coordinator: AppCoordinator
    let settings: AppSettings
    let onShowMainWindow: () -> Void
    let onCheckForUpdates: () -> Void
    let onQuit: () -> Void

    @State private var elapsedSeconds: Int = 0
    @State private var timerTask: Task<Void, Never>?

    private var recordingStartedAt: Date? {
        if case .recording(let metadata) = coordinator.state {
            return metadata.startedAt
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            statusLine
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            Divider()

            primaryAction
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            if coordinator.isRecording {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    captureRow(title: "You", status: coordinator.transcriptionEngine?.micCaptureStatus ?? .idle(.microphone))
                    captureRow(title: "Them", status: coordinator.transcriptionEngine?.systemAudioCaptureStatus ?? .idle(.systemAudio))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }

            Divider()

            Button(action: onShowMainWindow) {
                HStack {
                    Text("Show Query")
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Button(action: onCheckForUpdates) {
                HStack {
                    Text("Check for Updates…")
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Button(action: {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }) {
                HStack {
                    Text("Settings…")
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            Button(action: onQuit) {
                HStack {
                    Text("Quit Query")
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .padding(.bottom, 4)
        }
        .frame(width: 280)
        .onAppear {
            if coordinator.isRecording {
                startTimer()
            }
        }
        .onDisappear {
            stopTimer()
        }
        .onChange(of: coordinator.isRecording) { _, recording in
            if recording {
                startTimer()
            } else {
                stopTimer()
            }
        }
    }

    private var statusLine: some View {
        HStack(spacing: 6) {
            if coordinator.isRecording {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                Text("Recording - \(formattedTime)")
                    .font(.system(size: 13, weight: .medium))
            } else if settings.meetingAutoDetectEnabled {
                Circle()
                    .fill(.secondary)
                    .frame(width: 8, height: 8)
                Text("Meeting detection on")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            } else {
                Circle()
                    .fill(.secondary.opacity(0.5))
                    .frame(width: 8, height: 8)
                Text("Idle")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var primaryAction: some View {
        if coordinator.isRecording {
            Button(action: {
                coordinator.handle(.userStopped, settings: settings)
            }) {
                Text("Stop Recording")
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.regular)
        } else {
            Button(action: {
                guard settings.hasAcknowledgedRecordingConsent else {
                    onShowMainWindow()
                    return
                }
                coordinator.handle(.userStarted(.manual()), settings: settings)
            }) {
                Text("Start Recording")
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
    }

    private var formattedTime: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func captureRow(title: String, status: LiveCaptureStatus) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(captureColor(status))
                .frame(width: 7, height: 7)
            Text(title)
                .font(.system(size: 12, weight: .medium))
            Text(captureLabel(status))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .help(status.detail ?? captureLabel(status))
    }

    private func captureColor(_ status: LiveCaptureStatus) -> Color {
        switch status.health {
        case .active:
            return .green
        case .starting:
            return .yellow
        case .degraded:
            return .red
        case .idle:
            return .secondary.opacity(0.4)
        }
    }

    private func captureLabel(_ status: LiveCaptureStatus) -> String {
        switch status.health {
        case .active:
            return "Live"
        case .starting:
            return status.didRetry ? "Retrying" : "Starting"
        case .degraded:
            return "Unavailable"
        case .idle:
            return "Idle"
        }
    }

    private func startTimer() {
        updateElapsed()
        stopTimer()
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                updateElapsed()
            }
        }
    }

    private func updateElapsed() {
        if let start = recordingStartedAt {
            elapsedSeconds = max(0, Int(Date().timeIntervalSince(start)))
        } else {
            elapsedSeconds = 0
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
        elapsedSeconds = 0
    }
}
