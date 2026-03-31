import SwiftUI

struct GuidancePanelView: View {
    let interviewSetup: InterviewSetup
    let transcript: [Utterance]
    let notes: [BANote]
    let interviewTags: [InterviewTag]
    let screenshots: [ScreenshotCapture]

    @State private var now = Date()

    private var snapshot: GuidanceSnapshot {
        QueryGuidanceEngine.analyze(
            interviewSetup: interviewSetup,
            utterances: transcript,
            notes: notes,
            tags: interviewTags,
            screenshots: screenshots,
            now: now
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            panelHeader

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    coverageSection
                    guidanceSection
                }
                .padding(16)
            }
        }
        .background(Color.primary.opacity(0.02))
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                now = .now
            }
        }
    }

    // MARK: - Header

    private var panelHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Guidance")
                .font(.system(size: 12, weight: .semibold))

            if !interviewSetup.processArea.isEmpty {
                Text(interviewSetup.processArea)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Coverage

    private var coverageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Coverage")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text("\(snapshot.filledSlots.count) of \(snapshot.slotStates.count) slots captured")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: 4) {
                ForEach(snapshot.slotStates, id: \.slot.rawValue) { state in
                    slotRow(state)
                }
            }
        }
    }

    private func slotRow(_ state: DomainSlotState) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: state.isFilled ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 10))
                    .foregroundStyle(state.isFilled ? Color.green : Color.secondary.opacity(0.4))

                Text(state.slot.displayLabel)
                    .font(.system(size: 11, weight: state.isFilled ? .medium : .regular))
                    .foregroundStyle(state.isFilled ? Color.primary : Color.secondary)
            }

            if let snippet = state.snippets.last {
                Text(snippet)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .padding(.leading, 16)
            }
        }
    }

    // MARK: - Guidance Hints

    private var guidanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Questioning Mode")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            if let hint = snapshot.recommendedHint {
                guidanceCard(hint: hint)
            } else {
                waitingCard
            }
        }
    }

    private func guidanceCard(hint: GuidanceHint) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                modeChip(title: "Detected", value: snapshot.detectedMode.displayLabel, tint: .secondary)
                modeChip(title: "Shift", value: hint.mode.displayLabel, tint: .accentColor)
            }

            Text(hint.reason)
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                Text("Try asking")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                ForEach(hint.examplePrompts, id: \.self) { prompt in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "quote.bubble")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.accentColor)
                            .padding(.top, 2)
                        Text(prompt)
                            .font(.system(size: 11))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if !hint.missingSlots.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Missing coverage")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 84), alignment: .leading)],
                        alignment: .leading,
                        spacing: 6
                    ) {
                        ForEach(hint.missingSlots, id: \.rawValue) { slot in
                            Text(slot.displayLabel)
                                .font(.system(size: 10, weight: .medium))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(Color.primary.opacity(0.05))
                                .foregroundStyle(.secondary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.accentColor.opacity(0.14), lineWidth: 1)
        )
    }

    private var waitingCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                Text("Waiting for evidence\u{2026}")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Text("Guidance will adapt as transcript, notes, tags, and screenshots accumulate.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.orange.opacity(0.1), lineWidth: 1)
        )
    }

    private func modeChip(title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(tint.opacity(0.08))
        .clipShape(Capsule())
    }
}
