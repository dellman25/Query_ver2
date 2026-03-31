import SwiftUI

struct InterviewWorkspaceView: View {
    let controllerState: LiveSessionState
    let sessionTitle: String
    let interviewSetup: InterviewSetup
    @Binding var notes: [BANote]
    @Binding var interviewTags: [InterviewTag]
    @Binding var screenshots: [ScreenshotCapture]
    let onStop: () -> Void
    let onMuteToggle: () -> Void
    let onCaptureScreenshot: () -> Void
    let onToggleScreenshotVisibility: () -> Void

    @State private var noteText = ""
    @State private var selectedTags: Set<InterviewTagKind> = []
    @FocusState private var isNoteFieldFocused: Bool

    private enum NotesTab: String, CaseIterable {
        case notes = "Notes"
        case timeline = "Timeline"
    }
    @State private var notesTab: NotesTab = .notes

    var body: some View {
        VStack(spacing: 0) {
            workspaceHeader

            Divider()

            HStack(spacing: 0) {
                transcriptPanel
                    .frame(minWidth: 240, idealWidth: 320)

                Divider()

                notesPanel
                    .frame(minWidth: 260, idealWidth: 380)

                Divider()

                GuidancePanelView(
                    interviewSetup: interviewSetup,
                    transcript: controllerState.liveTranscript,
                    notes: notes,
                    interviewTags: interviewTags,
                    screenshots: screenshots,
                    aiStatus: controllerState.aiStatus
                )
                    .frame(minWidth: 200, idealWidth: 260, maxWidth: 300)
            }

            Divider()

            controlBar
        }
    }

    // MARK: - Header

    private var workspaceHeader: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Circle()
                    .fill(controllerState.isMicMuted ? Color.red : Color.green)
                    .frame(width: 8, height: 8)
                    .scaleEffect(
                        controllerState.isMicMuted
                            ? 1.0
                            : 1.0 + CGFloat(controllerState.audioLevel) * 0.4
                    )
                    .animation(.easeOut(duration: 0.1), value: controllerState.audioLevel)

                Text(controllerState.isMicMuted ? "Muted" : "Recording")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(controllerState.isMicMuted ? .red : .green)
            }

            Text(sessionTitle.isEmpty ? "Untitled Session" : sessionTitle)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)

            if !interviewSetup.intervieweeRole.isEmpty {
                Text("\u{00B7}")
                    .foregroundStyle(.tertiary)
                Text(interviewSetup.intervieweeRole)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            captureBadge(title: "You", systemImage: "mic.fill", status: controllerState.micCaptureStatus)
            captureBadge(title: "Them", systemImage: "speaker.wave.2.fill", status: controllerState.systemAudioCaptureStatus)

            Spacer()

            Text(controllerState.modelDisplayName)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.04))
                .clipShape(Capsule())

            Button(action: onStop) {
                HStack(spacing: 4) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 9))
                    Text("End")
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.red.opacity(0.1))
                .foregroundStyle(.red)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Stop recording and end interview")
            .accessibilityIdentifier("app.workspace.stop")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func captureBadge(title: String, systemImage: String, status: LiveCaptureStatus) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 9, weight: .medium))
            Circle()
                .fill(captureStatusColor(status))
                .frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: 10, weight: .medium))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(captureStatusColor(status).opacity(0.08))
        .foregroundStyle(captureStatusColor(status))
        .clipShape(Capsule())
        .help(status.detail ?? "\(title) is \(captureStatusLabel(status)).")
    }

    private func captureStatusColor(_ status: LiveCaptureStatus) -> Color {
        switch status.health {
        case .active:
            return .green
        case .starting:
            return .yellow
        case .degraded:
            return .red
        case .idle:
            return .secondary
        }
    }

    private func captureStatusLabel(_ status: LiveCaptureStatus) -> String {
        switch status.health {
        case .active:
            return "active"
        case .starting:
            return "starting"
        case .degraded:
            return "degraded"
        case .idle:
            return "idle"
        }
    }

    // MARK: - Transcript Panel (Left)

    private var transcriptPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Transcript")
                    .font(.system(size: 12, weight: .semibold))
                if !controllerState.liveTranscript.isEmpty {
                    Text("(\(controllerState.liveTranscript.count))")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            TranscriptView(
                utterances: controllerState.liveTranscript,
                volatileYouText: controllerState.volatileYouText,
                volatileThemText: controllerState.volatileThemText,
                showSearch: true
            )
        }
    }

    // MARK: - Notes Panel (Center)

    private var notesPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            notesPanelHeader

            Divider()

            noteInputSection

            Divider()

            tagBar

            Divider()

            switch notesTab {
            case .notes:
                eventsList
            case .timeline:
                timelineList
            }
        }
    }

    private var notesPanelHeader: some View {
        HStack(spacing: 8) {
            Picker("View", selection: $notesTab) {
                ForEach(NotesTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 180)

            let totalEvents = notes.count + interviewTags.count + screenshots.count
            if totalEvents > 0 {
                Text("(\(totalEvents))")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Note Input

    private var noteInputSection: some View {
        HStack(alignment: .top, spacing: 8) {
            TextField("Type a note\u{2026}", text: $noteText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .lineLimit(1...4)
                .focused($isNoteFieldFocused)
                .onSubmit { submitNote() }
                .accessibilityLabel("Note input")

            Button(action: submitNote) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(
                        noteText.trimmingCharacters(in: .whitespaces).isEmpty
                            ? Color.primary.opacity(0.15)
                            : Color.accentColor
                    )
            }
            .buttonStyle(.plain)
            .disabled(noteText.trimmingCharacters(in: .whitespaces).isEmpty)
            .help("Add note (\u{21A9})")
            .accessibilityIdentifier("app.workspace.addNote")

            Button(action: submitQuickTag) {
                Image(systemName: "tag.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(
                        selectedTags.isEmpty
                            ? Color.primary.opacity(0.15)
                            : Color.orange
                    )
            }
            .buttonStyle(.plain)
            .disabled(selectedTags.isEmpty)
            .help("Add standalone tag at current timestamp")
            .accessibilityLabel("Quick tag")
            .accessibilityIdentifier("app.workspace.quickTag")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Tag Bar

    private var tagBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(InterviewTagKind.allCases) { kind in
                    tagChip(kind)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    private func tagChip(_ kind: InterviewTagKind) -> some View {
        let isSelected = selectedTags.contains(kind)
        return Button {
            if isSelected {
                selectedTags.remove(kind)
            } else {
                selectedTags.insert(kind)
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: kind.systemImage)
                    .font(.system(size: 9))
                Text(kind.displayLabel)
                    .font(.system(size: 10, weight: .medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                isSelected
                    ? Color.accentColor.opacity(0.12)
                    : Color.primary.opacity(0.04)
            )
            .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("Tag note as \(kind.displayLabel)")
        .accessibilityLabel("Tag: \(kind.displayLabel)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Events List (Notes + Screenshots + Tags)

    private var eventsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                let events = buildNotesPanelEvents()
                if events.isEmpty {
                    emptyNotesPlaceholder
                } else {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(events) { event in
                            eventRow(event)
                                .id(event.id)
                        }
                    }
                    .padding(12)
                }
            }
            .onChange(of: notes.count) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: interviewTags.count) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: screenshots.count) {
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        let events = buildNotesPanelEvents()
        if let last = events.last {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private var emptyNotesPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 20))
                .foregroundStyle(.tertiary)
            Text("Notes will appear here")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
            Text("Type a note above and press Return to add it. Select tags before adding to categorize.")
                .font(.system(size: 11))
                .foregroundStyle(.quaternary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding(16)
    }

    /// Merge notes, standalone tags, and screenshots into a chronological list.
    private func buildNotesPanelEvents() -> [TimelineEvent] {
        var events: [TimelineEvent] = []
        for note in notes {
            events.append(.note(note))
        }
        for tag in interviewTags {
            events.append(.tag(tag))
        }
        for shot in screenshots {
            events.append(.screenshot(shot))
        }
        return events.sorted { $0.timestamp < $1.timestamp }
    }

    @ViewBuilder
    private func eventRow(_ event: TimelineEvent) -> some View {
        switch event {
        case .note(let note):
            noteRow(note)
        case .tag(let tag):
            standaloneTagRow(tag)
        case .screenshot(let capture):
            screenshotRow(capture)
        case .transcript:
            EmptyView()
        }
    }

    private func noteRow(_ note: BANote) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(noteTimestamp.string(from: note.timestamp))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .frame(width: 40, alignment: .trailing)

                Image(systemName: "pencil.line")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)

                Text(note.text)
                    .font(.system(size: 12))
                    .textSelection(.enabled)
            }

            if !note.tags.isEmpty {
                HStack(spacing: 4) {
                    Spacer().frame(width: 40)
                    ForEach(note.tags, id: \.rawValue) { tag in
                        HStack(spacing: 2) {
                            Image(systemName: tag.systemImage)
                                .font(.system(size: 8))
                            Text(tag.displayLabel)
                                .font(.system(size: 9, weight: .medium))
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.08))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
    }

    private func standaloneTagRow(_ tag: InterviewTag) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(noteTimestamp.string(from: tag.timestamp))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 40, alignment: .trailing)

            HStack(spacing: 3) {
                Image(systemName: tag.kind.systemImage)
                    .font(.system(size: 9))
                Text(tag.kind.displayLabel)
                    .font(.system(size: 10, weight: .medium))
                if let label = tag.label, !label.isEmpty {
                    Text("\u{00B7} \(label)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.orange.opacity(0.08))
            .foregroundStyle(.orange)
            .clipShape(Capsule())
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
    }

    private func screenshotRow(_ capture: ScreenshotCapture) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(noteTimestamp.string(from: capture.timestamp))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 40, alignment: .trailing)

            HStack(spacing: 4) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 10))
                Text(capture.label ?? "Screenshot")
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.purple.opacity(0.08))
            .foregroundStyle(.purple)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
    }

    // MARK: - Timeline List (Transcript + Notes + Tags + Screenshots)

    private var timelineList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                let events = buildFullTimeline()
                if events.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "clock")
                            .font(.system(size: 20))
                            .foregroundStyle(.tertiary)
                        Text("Timeline will appear here")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 100)
                    .padding(16)
                } else {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(events) { event in
                            timelineEventRow(event)
                                .id(event.id)
                        }
                    }
                    .padding(12)
                }
            }
            .onChange(of: controllerState.liveTranscript.count) {
                if let last = controllerState.liveTranscript.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func buildFullTimeline() -> [TimelineEvent] {
        var events: [TimelineEvent] = []
        for u in controllerState.liveTranscript {
            events.append(.transcript(u))
        }
        for note in notes {
            events.append(.note(note))
        }
        for tag in interviewTags {
            events.append(.tag(tag))
        }
        for shot in screenshots {
            events.append(.screenshot(shot))
        }
        return events.sorted { $0.timestamp < $1.timestamp }
    }

    @ViewBuilder
    private func timelineEventRow(_ event: TimelineEvent) -> some View {
        switch event {
        case .transcript(let u):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(noteTimestamp.string(from: u.timestamp))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .frame(width: 40, alignment: .trailing)
                Text(u.speaker.displayLabel)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(u.speaker.color)
                    .frame(minWidth: 28, alignment: .trailing)
                Text(u.displayText)
                    .font(.system(size: 12))
                    .textSelection(.enabled)
            }
            .padding(.vertical, 2)
        case .note(let note):
            noteRow(note)
                .background(Color.accentColor.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        case .tag(let tag):
            standaloneTagRow(tag)
        case .screenshot(let capture):
            screenshotRow(capture)
        }
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        HStack(spacing: 10) {
            Button(action: onMuteToggle) {
                HStack(spacing: 5) {
                    Image(systemName: controllerState.isMicMuted ? "mic.slash.fill" : "mic.fill")
                        .font(.system(size: 11))
                    Text(controllerState.isMicMuted ? "Unmute" : "Mute")
                        .font(.system(size: 11))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(controllerState.isMicMuted ? Color.red.opacity(0.1) : Color.primary.opacity(0.05))
                .foregroundStyle(controllerState.isMicMuted ? .red : .secondary)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help(controllerState.isMicMuted ? "Unmute microphone" : "Mute microphone")
            .accessibilityIdentifier("app.controlBar.muteToggle")

            AudioLevelView(level: controllerState.audioLevel)
                .frame(width: 40, height: 14)
                .opacity(controllerState.isMicMuted ? 0.3 : 1.0)

            Button(action: onCaptureScreenshot) {
                HStack(spacing: 5) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 11))
                    Text("Screenshot")
                        .font(.system(size: 11))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.purple.opacity(0.08))
                .foregroundStyle(.purple)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Capture a screenshot linked to the current transcript position (\u{2318}\u{21E7}S)")
            .accessibilityLabel("Capture screenshot")
            .accessibilityIdentifier("app.controlBar.screenshot")

            Button(action: onToggleScreenshotVisibility) {
                HStack(spacing: 5) {
                    Image(systemName: controllerState.screenshotVisibilityEnabled ? "eye.fill" : "eye.slash.fill")
                        .font(.system(size: 11))
                    Text(controllerState.screenshotVisibilityEnabled ? "Screenshots On" : "Allow Screenshots")
                        .font(.system(size: 11))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    controllerState.screenshotVisibilityEnabled
                        ? Color.blue.opacity(0.12)
                        : Color.primary.opacity(0.05)
                )
                .foregroundStyle(controllerState.screenshotVisibilityEnabled ? .blue : .secondary)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Temporarily make Query visible to macOS screenshots and screen capture tools.")
            .accessibilityIdentifier("app.controlBar.screenshotVisibility")

            Spacer()

            if let warning = controllerState.sessionWarnings.first {
                Text(warning.message)
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .lineLimit(1)
            }

            if let error = controllerState.errorMessage {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Actions

    private func submitNote() {
        let trimmed = noteText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let note = BANote(text: trimmed, tags: Array(selectedTags))
        notes.append(note)
        noteText = ""
        selectedTags.removeAll()
        isNoteFieldFocused = true
    }

    private func submitQuickTag() {
        guard !selectedTags.isEmpty else { return }
        let nearestUtteranceID = controllerState.liveTranscript.last?.id
        for kind in selectedTags {
            let tag = InterviewTag(
                kind: kind,
                transcriptSegmentID: nearestUtteranceID
            )
            interviewTags.append(tag)
        }
        selectedTags.removeAll()
        isNoteFieldFocused = true
    }
}

// MARK: - Formatters

private let noteTimestamp: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
    return f
}()
