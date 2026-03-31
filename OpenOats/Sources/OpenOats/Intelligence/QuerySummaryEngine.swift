import Foundation

struct QuerySummaryEngine {
    struct SessionContext {
        let sessionID: String
        let title: String?
        let startedAt: Date?
        let interviewSetup: InterviewSetup?

        init(
            sessionID: String,
            title: String?,
            startedAt: Date?,
            interviewSetup: InterviewSetup?
        ) {
            self.sessionID = sessionID
            self.title = title
            self.startedAt = startedAt
            self.interviewSetup = interviewSetup
        }
    }

    static func generate(
        context: SessionContext,
        transcript: [SessionRecord],
        notes: [BANote],
        tags: [InterviewTag],
        screenshots: [ScreenshotCapture],
        generatedAt: Date = .now
    ) -> SummaryArtifact {
        let interviewSetup = context.interviewSetup ?? InterviewSetup()
        let utterances = transcript.map {
            Utterance(
                text: $0.text,
                speaker: $0.speaker,
                timestamp: $0.timestamp,
                refinedText: $0.refinedText
            )
        }
        let guidance = QueryGuidanceEngine.analyze(
            interviewSetup: interviewSetup,
            utterances: utterances,
            notes: notes,
            tags: tags,
            screenshots: screenshots,
            now: generatedAt
        )

        var collector = FactCollector(
            transcript: transcript,
            notes: notes,
            tags: tags,
            screenshots: screenshots
        )
        collector.collectTaggedNotes()
        collector.collectTaggedMoments()
        collector.collectTranscriptFacts()
        collector.collectNoteFacts()
        collector.collectScreenshotFacts()

        let explicitFacts = collector.facts
        let inferredRequirements = buildRequirementDrafts(from: explicitFacts)
        let extractedFacts = explicitFacts + inferredRequirements
        let openQuestions = extractedFacts
            .filter { $0.kind == .openQuestion }
            .map(\.text)

        let sessionSummary = buildSessionSummary(
            context: context,
            transcriptCount: transcript.count,
            noteCount: notes.count,
            tagCount: tags.count,
            screenshotCount: screenshots.count,
            extractedFacts: extractedFacts
        )
        let processUnderstanding = buildProcessUnderstanding(
            context: context,
            slotStates: guidance.slotStates
        )
        let markdown = buildMarkdown(
            context: context,
            generatedAt: generatedAt,
            sessionSummary: sessionSummary,
            processUnderstanding: processUnderstanding,
            extractedFacts: extractedFacts,
            openQuestions: openQuestions,
            slotStates: guidance.slotStates
        )

        return SummaryArtifact(
            generatedAt: generatedAt,
            sessionSummary: sessionSummary,
            processUnderstanding: processUnderstanding,
            extractedFacts: extractedFacts,
            openQuestions: openQuestions,
            coverageSnapshot: guidance.slotStates,
            markdown: markdown
        )
    }
}

private extension QuerySummaryEngine {
    struct FactCollector {
        private(set) var facts: [ExtractedFact] = []

        let transcript: [SessionRecord]
        let notes: [BANote]
        let tags: [InterviewTag]
        let screenshots: [ScreenshotCapture]

        private let noteLookup: [UUID: BANote]
        private var seenKeys = Set<String>()

        init(
            transcript: [SessionRecord],
            notes: [BANote],
            tags: [InterviewTag],
            screenshots: [ScreenshotCapture]
        ) {
            self.transcript = transcript
            self.notes = notes
            self.tags = tags
            self.screenshots = screenshots
            self.noteLookup = Dictionary(uniqueKeysWithValues: notes.map { ($0.id, $0) })
        }

        mutating func collectTaggedNotes() {
            for note in notes {
                let baseEvidence = [noteEvidence(note)]
                for tag in note.tags {
                    addFact(
                        kind: factKind(for: tag),
                        text: note.text,
                        evidence: baseEvidence + nearbyTranscriptEvidence(at: note.timestamp) + nearbyScreenshotEvidence(at: note.timestamp),
                        isInferred: false
                    )
                }
                if isQuestion(note.text) {
                    addFact(
                        kind: .openQuestion,
                        text: note.text,
                        evidence: baseEvidence + nearbyTranscriptEvidence(at: note.timestamp),
                        isInferred: false
                    )
                }
            }
        }

        mutating func collectTaggedMoments() {
            for tag in tags {
                let linkedNoteText = tag.noteID.flatMap { noteLookup[$0]?.text }
                let fallbackText =
                    compactSnippet(tag.label)
                    ?? linkedNoteText
                    ?? nearestTranscriptText(at: tag.timestamp)
                    ?? tag.kind.displayLabel
                addFact(
                    kind: factKind(for: tag.kind),
                    text: fallbackText,
                    evidence: [tagEvidence(tag)] + nearbyTranscriptEvidence(at: tag.timestamp) + nearbyScreenshotEvidence(at: tag.timestamp),
                    isInferred: false
                )
            }
        }

        mutating func collectTranscriptFacts() {
            for record in transcript {
                let text = record.refinedText ?? record.text
                let normalized = normalize(text)
                guard !normalized.isEmpty else { continue }

                let evidence = [transcriptEvidence(record)] + nearbyScreenshotEvidence(at: record.timestamp)
                if containsAny(normalized, actionKeywords) {
                    addFact(kind: .processStep, text: text, evidence: evidence, isInferred: false)
                }
                if containsAny(normalized, decisionKeywords) {
                    addFact(kind: .businessRule, text: text, evidence: evidence, isInferred: false)
                }
                if containsAny(normalized, exceptionKeywords) {
                    addFact(kind: .exception, text: text, evidence: evidence, isInferred: false)
                }
                if containsAny(normalized, controlKeywords) {
                    addFact(kind: .control, text: text, evidence: evidence, isInferred: false)
                }
                if containsAny(normalized, dataKeywords) {
                    addFact(kind: .dataElement, text: text, evidence: evidence, isInferred: false)
                }
                if containsAny(normalized, painPointKeywords) {
                    addFact(kind: .painPoint, text: text, evidence: evidence, isInferred: false)
                }
                if containsAny(normalized, metricKeywords) {
                    addFact(kind: .metric, text: text, evidence: evidence, isInferred: false)
                }
                if isQuestion(text) {
                    addFact(kind: .openQuestion, text: text, evidence: evidence, isInferred: false)
                }
            }
        }

        mutating func collectNoteFacts() {
            for note in notes where note.tags.isEmpty {
                let normalized = normalize(note.text)
                guard !normalized.isEmpty else { continue }

                let evidence = [noteEvidence(note)] + nearbyTranscriptEvidence(at: note.timestamp) + nearbyScreenshotEvidence(at: note.timestamp)
                if containsAny(normalized, decisionKeywords) {
                    addFact(kind: .businessRule, text: note.text, evidence: evidence, isInferred: false)
                }
                if containsAny(normalized, exceptionKeywords) {
                    addFact(kind: .exception, text: note.text, evidence: evidence, isInferred: false)
                }
                if containsAny(normalized, controlKeywords) {
                    addFact(kind: .control, text: note.text, evidence: evidence, isInferred: false)
                }
                if containsAny(normalized, dataKeywords) {
                    addFact(kind: .dataElement, text: note.text, evidence: evidence, isInferred: false)
                }
                if containsAny(normalized, metricKeywords) {
                    addFact(kind: .metric, text: note.text, evidence: evidence, isInferred: false)
                }
                if containsAny(normalized, painPointKeywords) {
                    addFact(kind: .painPoint, text: note.text, evidence: evidence, isInferred: false)
                }
            }
        }

        mutating func collectScreenshotFacts() {
            for screenshot in screenshots {
                guard let label = compactSnippet(screenshot.label) else { continue }
                let normalized = normalize(label)
                let evidence = [screenshotEvidence(screenshot)] + nearbyTranscriptEvidence(at: screenshot.timestamp)

                if containsAny(normalized, outputKeywords) {
                    addFact(kind: .dataElement, text: label, evidence: evidence, isInferred: false)
                }
                if containsAny(normalized, metricKeywords) {
                    addFact(kind: .metric, text: label, evidence: evidence, isInferred: false)
                }
            }
        }

        mutating func addFact(
            kind: ExtractedFactKind,
            text: String,
            evidence: [EvidenceReference],
            isInferred: Bool
        ) {
            let cleaned = cleanFactText(text)
            guard !cleaned.isEmpty else { return }

            let key = "\(kind.rawValue)|\(normalize(cleaned))"
            guard !seenKeys.contains(key) else { return }
            seenKeys.insert(key)

            facts.append(
                ExtractedFact(
                    kind: kind,
                    text: cleaned,
                    evidence: dedupeEvidence(evidence),
                    isInferred: isInferred
                )
            )
        }

        private func nearbyTranscriptEvidence(at timestamp: Date) -> [EvidenceReference] {
            transcript
                .filter { abs($0.timestamp.timeIntervalSince(timestamp)) <= 75 }
                .sorted { abs($0.timestamp.timeIntervalSince(timestamp)) < abs($1.timestamp.timeIntervalSince(timestamp)) }
                .prefix(1)
                .map(transcriptEvidence)
        }

        private func nearbyScreenshotEvidence(at timestamp: Date) -> [EvidenceReference] {
            screenshots
                .filter { abs($0.timestamp.timeIntervalSince(timestamp)) <= 90 }
                .sorted { abs($0.timestamp.timeIntervalSince(timestamp)) < abs($1.timestamp.timeIntervalSince(timestamp)) }
                .prefix(1)
                .map(screenshotEvidence)
        }

        private func nearestTranscriptText(at timestamp: Date) -> String? {
            transcript
                .min(by: { abs($0.timestamp.timeIntervalSince(timestamp)) < abs($1.timestamp.timeIntervalSince(timestamp)) })
                .map { $0.refinedText ?? $0.text }
        }
    }

    static func buildRequirementDrafts(from facts: [ExtractedFact]) -> [ExtractedFact] {
        var drafts: [ExtractedFact] = []
        var seen = Set<String>()

        for fact in facts where fact.kind != .openQuestion && fact.kind != .requirementDraft {
            let text = requirementDraftText(for: fact)
            let key = normalize(text)
            guard !text.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            drafts.append(
                ExtractedFact(
                    kind: .requirementDraft,
                    text: text,
                    evidence: fact.evidence,
                    isInferred: true
                )
            )
        }

        return Array(drafts.prefix(8))
    }

    static func requirementDraftText(for fact: ExtractedFact) -> String {
        switch fact.kind {
        case .processStep:
            return "The workflow should support this step reliably: \(fact.text)"
        case .businessRule:
            return "The process should enforce the business rule: \(fact.text)"
        case .exception:
            return "The future design should explicitly handle this exception path: \(fact.text)"
        case .control:
            return "The process should preserve this control or risk check: \(fact.text)"
        case .dataElement:
            return "The workflow should capture or surface the required data element: \(fact.text)"
        case .painPoint:
            return "The future workflow should reduce this operational pain point: \(fact.text)"
        case .metric:
            return "The process should support measurement or reporting for: \(fact.text)"
        case .openQuestion, .requirementDraft:
            return ""
        }
    }

    static func buildSessionSummary(
        context: SessionContext,
        transcriptCount: Int,
        noteCount: Int,
        tagCount: Int,
        screenshotCount: Int,
        extractedFacts: [ExtractedFact]
    ) -> String {
        let processArea = context.interviewSetup?.processArea.trimmingCharacters(in: .whitespacesAndNewlines)
        let role = context.interviewSetup?.intervieweeRole.trimmingCharacters(in: .whitespacesAndNewlines)
        let subject = nonEmpty(processArea) ?? "the workflow"
        let actor = nonEmpty(role) ?? "the interview subject"

        let explicitFacts = extractedFacts.filter { !$0.isInferred && $0.kind != .requirementDraft }
        let businessRuleCount = explicitFacts.filter { $0.kind == .businessRule }.count
        let exceptionCount = explicitFacts.filter { $0.kind == .exception }.count
        let painPointCount = explicitFacts.filter { $0.kind == .painPoint }.count

        let counts = "Evidence captured across \(transcriptCount) transcript entries, \(noteCount) BA notes, \(tagCount) tags, and \(screenshotCount) screenshots."
        let findings = "The session surfaced \(businessRuleCount) business rules, \(exceptionCount) exceptions, and \(painPointCount) pain points."
        return "This interview covered \(subject) with \(actor). \(counts) \(findings)"
    }

    static func buildProcessUnderstanding(
        context: SessionContext,
        slotStates: [DomainSlotState]
    ) -> String {
        let filled = Dictionary(uniqueKeysWithValues: slotStates.filter(\.isFilled).map { ($0.slot, $0.snippets) })
        var sentences: [String] = []

        if let actor = filled[.actor]?.first {
            sentences.append("Primary actor: \(actor).")
        }
        if let purpose = filled[.processPurpose]?.first {
            sentences.append("Process purpose: \(purpose).")
        }
        if let trigger = filled[.trigger]?.first {
            sentences.append("Trigger: \(trigger).")
        }
        if let step = filled[.stepAction]?.first {
            sentences.append("Observed workflow step: \(step).")
        }
        if let decision = filled[.decisionRule]?.first {
            sentences.append("Decision logic in play: \(decision).")
        }
        if let output = filled[.outputReport]?.first {
            sentences.append("Outputs or reports mentioned: \(output).")
        }
        if let painPoint = filled[.painPoint]?.first {
            sentences.append("Current friction point: \(painPoint).")
        }

        if sentences.isEmpty {
            let fallback = context.interviewSetup?.objective.trimmingCharacters(in: .whitespacesAndNewlines)
            return nonEmpty(fallback) ?? "The process understanding is still thin; review the transcript and captured evidence for follow-up."
        }

        return sentences.joined(separator: " ")
    }

    static func buildMarkdown(
        context: SessionContext,
        generatedAt: Date,
        sessionSummary: String,
        processUnderstanding: String,
        extractedFacts: [ExtractedFact],
        openQuestions: [String],
        slotStates: [DomainSlotState]
    ) -> String {
        let title = nonEmpty(context.title) ?? nonEmpty(context.interviewSetup?.processArea) ?? "Interview Summary"
        var lines: [String] = []
        lines.append("# \(title)")
        lines.append("")
        lines.append("## Session Metadata")
        lines.append("")
        lines.append("- Session ID: \(context.sessionID)")
        lines.append("- Generated: \(markdownTimestamp.string(from: generatedAt))")
        if let startedAt = context.startedAt {
            lines.append("- Session Start: \(markdownTimestamp.string(from: startedAt))")
        }
        if let processArea = nonEmpty(context.interviewSetup?.processArea) {
            lines.append("- Process Area: \(processArea)")
        }
        if let role = nonEmpty(context.interviewSetup?.intervieweeRole) {
            lines.append("- Interviewee Role: \(role)")
        }
        if let objective = nonEmpty(context.interviewSetup?.objective) {
            lines.append("- Objective: \(objective)")
        }
        lines.append("")
        lines.append("## Session Summary")
        lines.append("")
        lines.append(sessionSummary)
        lines.append("")
        lines.append("## Process Understanding")
        lines.append("")
        lines.append(processUnderstanding)
        lines.append("")
        lines.append("## Coverage Snapshot")
        lines.append("")
        let captured = slotStates.filter(\.isFilled).map { $0.slot.displayLabel }
        let missing = slotStates.filter { !$0.isFilled }.map { $0.slot.displayLabel }
        lines.append("- Captured: \(captured.isEmpty ? "None yet" : captured.joined(separator: ", "))")
        lines.append("- Still thin: \(missing.isEmpty ? "None" : missing.joined(separator: ", "))")
        lines.append("")

        let keyFindings = extractedFacts.filter { !$0.isInferred && $0.kind != .openQuestion && $0.kind != .requirementDraft }
        if !keyFindings.isEmpty {
            lines.append("## Key Findings")
            lines.append("")
            for fact in keyFindings.prefix(6) {
                lines.append("- \(fact.text)")
            }
            lines.append("")
        }

        let groupedFacts = ExtractedFactKind.allCases.compactMap { kind -> (ExtractedFactKind, [ExtractedFact])? in
            guard kind != .requirementDraft, kind != .openQuestion else { return nil }
            let matches = extractedFacts.filter { $0.kind == kind }
            guard !matches.isEmpty else { return nil }
            return (kind, matches)
        }
        if !groupedFacts.isEmpty {
            lines.append("## Extracted Objects")
            lines.append("")
            for (kind, facts) in groupedFacts {
                lines.append("### \(sectionTitle(for: kind))")
                lines.append("")
                lines.append(contentsOf: formatFacts(facts))
                lines.append("")
            }
        }

        let drafts = extractedFacts.filter { $0.kind == .requirementDraft }
        if !drafts.isEmpty {
            lines.append("## Draft Requirements")
            lines.append("")
            lines.append(contentsOf: formatFacts(drafts))
            lines.append("")
        }

        lines.append("## Open Questions")
        lines.append("")
        if openQuestions.isEmpty {
            lines.append("- No explicit open questions were captured.")
        } else {
            for question in openQuestions {
                lines.append("- \(question)")
            }
        }
        lines.append("")

        let uniqueEvidence = dedupeEvidence(extractedFacts.flatMap(\.evidence))
        if !uniqueEvidence.isEmpty {
            lines.append("## Evidence References")
            lines.append("")
            for evidence in uniqueEvidence {
                lines.append("- \(formatEvidence(evidence))")
            }
        }

        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }

    static func formatFacts(_ facts: [ExtractedFact]) -> [String] {
        var lines: [String] = []
        for fact in facts {
            lines.append("- \(fact.text) [\(fact.statusLabel)]")
            if fact.evidence.isEmpty {
                lines.append("  - Evidence: none captured")
            } else {
                lines.append("  - Evidence: \(fact.evidence.map(formatEvidence).joined(separator: "; "))")
            }
        }
        return lines
    }

    static func formatEvidence(_ evidence: EvidenceReference) -> String {
        let label: String
        switch evidence.sourceKind {
        case .transcript:
            label = "Transcript"
        case .note:
            label = "Note"
        case .screenshot:
            label = "Screenshot"
        case .tag:
            label = "Tag"
        }

        let timestamp = evidence.timestamp.map { timeOnlyTimestamp.string(from: $0) } ?? "No time"
        let snippet = compactSnippet(evidence.snippet) ?? "No snippet"
        let status = evidence.isExplicit ? "explicit" : "inferred"
        return "\(label) \(timestamp): \(snippet) (\(status))"
    }

    static func factKind(for tag: InterviewTagKind) -> ExtractedFactKind {
        switch tag {
        case .businessRule:
            return .businessRule
        case .exception:
            return .exception
        case .control:
            return .control
        case .dataField:
            return .dataElement
        case .metric:
            return .metric
        case .painPoint:
            return .painPoint
        case .openQuestion:
            return .openQuestion
        }
    }

    static func sectionTitle(for kind: ExtractedFactKind) -> String {
        switch kind {
        case .processStep:
            return "Process Steps"
        case .businessRule:
            return "Business Rules"
        case .exception:
            return "Exceptions"
        case .control:
            return "Controls"
        case .dataElement:
            return "Data Elements"
        case .painPoint:
            return "Pain Points"
        case .metric:
            return "Metrics"
        case .openQuestion:
            return "Open Questions"
        case .requirementDraft:
            return "Draft Requirements"
        }
    }

    static func noteEvidence(_ note: BANote) -> EvidenceReference {
        EvidenceReference(
            sourceKind: .note,
            sourceID: note.id,
            timestamp: note.timestamp,
            snippet: cleanFactText(note.text),
            isExplicit: true
        )
    }

    static func tagEvidence(_ tag: InterviewTag) -> EvidenceReference {
        EvidenceReference(
            sourceKind: .tag,
            sourceID: tag.id,
            timestamp: tag.timestamp,
            snippet: cleanFactText(tag.label ?? tag.kind.displayLabel),
            isExplicit: true
        )
    }

    static func screenshotEvidence(_ screenshot: ScreenshotCapture) -> EvidenceReference {
        EvidenceReference(
            sourceKind: .screenshot,
            sourceID: screenshot.id,
            timestamp: screenshot.timestamp,
            snippet: cleanFactText(screenshot.label ?? screenshot.relativePath),
            isExplicit: true
        )
    }

    static func transcriptEvidence(_ record: SessionRecord) -> EvidenceReference {
        EvidenceReference(
            sourceKind: .transcript,
            sourceID: nil,
            timestamp: record.timestamp,
            snippet: cleanFactText(record.refinedText ?? record.text),
            isExplicit: true
        )
    }

    static func cleanFactText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func compactSnippet(_ text: String?) -> String? {
        guard let cleaned = text.map(cleanFactText), !cleaned.isEmpty else { return nil }
        guard cleaned.count > 120 else { return cleaned }
        let end = cleaned.index(cleaned.startIndex, offsetBy: 117)
        return "\(cleaned[..<end])..."
    }

    static func nonEmpty(_ text: String?) -> String? {
        guard let text else { return nil }
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    static func normalize(_ text: String) -> String {
        text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains(where: text.contains)
    }

    static func isQuestion(_ text: String) -> Bool {
        let normalized = normalize(text)
        return normalized.contains("?")
            || normalized.contains("follow up")
            || normalized.contains("need to confirm")
            || normalized.contains("clarify")
            || normalized.hasPrefix("what ")
            || normalized.hasPrefix("why ")
            || normalized.hasPrefix("how ")
    }

    static func dedupeEvidence(_ evidence: [EvidenceReference]) -> [EvidenceReference] {
        var seen = Set<String>()
        var result: [EvidenceReference] = []

        for item in evidence {
            let timestamp = item.timestamp.map { String($0.timeIntervalSince1970) } ?? "nil"
            let snippet = normalize(item.snippet ?? "")
            let key = "\(item.sourceKind.rawValue)|\(item.sourceID?.uuidString ?? "nil")|\(timestamp)|\(snippet)"
            if seen.insert(key).inserted {
                result.append(item)
            }
        }

        return result
    }

    static let markdownTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static let timeOnlyTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    static let actionKeywords = [
        "review", "check", "open", "click", "match", "reconcile", "send", "update", "move", "approve",
        "process", "submit", "enter", "book", "confirm", "escalate", "run"
    ]
    static let decisionKeywords = [
        "if", "depends", "unless", "threshold", "condition", "decide", "choice", "eligible", "status"
    ]
    static let exceptionKeywords = [
        "exception", "error", "fail", "fails", "failed", "wrong", "issue", "break", "manual", "escalation"
    ]
    static let controlKeywords = [
        "control", "risk", "check", "verify", "validate", "audit", "approval", "sign off", "reconcile"
    ]
    static let dataKeywords = [
        "field", "column", "amount", "date", "status", "reference", "id", "account", "value", "code"
    ]
    static let outputKeywords = [
        "report", "dashboard", "queue", "output", "export", "screen", "view", "filter", "sort", "column"
    ]
    static let painPointKeywords = [
        "pain", "manual", "slow", "delay", "workaround", "friction", "rekey", "duplicate", "missing"
    ]
    static let metricKeywords = [
        "sla", "kpi", "metric", "volume", "backlog", "aging", "turnaround", "within", "cutoff", "breach"
    ]
}
