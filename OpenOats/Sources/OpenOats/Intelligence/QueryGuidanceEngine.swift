import Foundation

struct QueryGuidanceEngine {
    static func analyze(
        interviewSetup: InterviewSetup,
        utterances: [Utterance],
        notes: [BANote],
        tags: [InterviewTag],
        screenshots: [ScreenshotCapture],
        now: Date = .now
    ) -> GuidanceSnapshot {
        var slotStates = Dictionary(
            uniqueKeysWithValues: DomainSlot.allCases.map { ($0, DomainSlotState(slot: $0)) }
        )

        func capture(_ slot: DomainSlot, snippet: String) {
            let cleaned = compactSnippet(snippet)
            guard !cleaned.isEmpty else { return }
            var state = slotStates[slot] ?? DomainSlotState(slot: slot)
            state.isFilled = true
            if !state.snippets.contains(cleaned) {
                state.snippets.append(cleaned)
                if state.snippets.count > 3 {
                    state.snippets.removeFirst(state.snippets.count - 3)
                }
            }
            slotStates[slot] = state
        }

        let trimmedObjective = interviewSetup.objective.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedObjective.isEmpty {
            capture(.processPurpose, snippet: trimmedObjective)
        }

        let trimmedRole = interviewSetup.intervieweeRole.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedRole.isEmpty {
            capture(.actor, snippet: trimmedRole)
        }

        let allSources = buildSources(
            interviewSetup: interviewSetup,
            utterances: utterances,
            notes: notes,
            tags: tags,
            screenshots: screenshots
        )

        for source in allSources {
            let normalized = normalize(source.text)
            guard !normalized.isEmpty else { continue }

            if containsAny(normalized, purposeKeywords) {
                capture(.processPurpose, snippet: source.text)
            }
            if containsAny(normalized, triggerKeywords) {
                capture(.trigger, snippet: source.text)
            }
            if containsAny(normalized, actorKeywords) {
                capture(.actor, snippet: source.text)
            }
            if containsAny(normalized, systemKeywords) {
                capture(.systemMentioned, snippet: source.text)
            }
            if containsAny(normalized, actionKeywords) {
                capture(.stepAction, snippet: source.text)
            }
            if containsAny(normalized, decisionKeywords) {
                capture(.decisionRule, snippet: source.text)
            }
            if containsAny(normalized, exceptionKeywords) {
                capture(.exceptionPath, snippet: source.text)
            }
            if containsAny(normalized, controlKeywords) {
                capture(.controlRationale, snippet: source.text)
            }
            if containsAny(normalized, dataKeywords) {
                capture(.dataNeeded, snippet: source.text)
            }
            if containsAny(normalized, outputKeywords) {
                capture(.outputReport, snippet: source.text)
            }
            if containsAny(normalized, painPointKeywords) {
                capture(.painPoint, snippet: source.text)
            }
            if containsAny(normalized, metricKeywords) {
                capture(.metricSLA, snippet: source.text)
            }
        }

        for tag in tags {
            let tagSnippet = tag.label ?? tag.kind.displayLabel
            switch tag.kind {
            case .businessRule:
                capture(.decisionRule, snippet: tagSnippet)
            case .exception:
                capture(.exceptionPath, snippet: tagSnippet)
            case .control:
                capture(.controlRationale, snippet: tagSnippet)
            case .dataField:
                capture(.dataNeeded, snippet: tagSnippet)
            case .metric:
                capture(.metricSLA, snippet: tagSnippet)
            case .painPoint:
                capture(.painPoint, snippet: tagSnippet)
            case .openQuestion:
                break
            }
        }

        let recentSignals = summarizeRecentSignals(
            utterances: utterances,
            notes: notes,
            screenshots: screenshots,
            now: now
        )
        let orderedStates = DomainSlot.allCases.map { slotStates[$0] ?? DomainSlotState(slot: $0) }
        let detectedMode = detectMode(from: recentSignals, hasTranscript: !utterances.isEmpty)
        let recommendedHint = recommendHint(
            interviewSetup: interviewSetup,
            slotStates: orderedStates,
            recentSignals: recentSignals,
            detectedMode: detectedMode
        )

        return GuidanceSnapshot(
            slotStates: orderedStates,
            detectedMode: detectedMode,
            recommendedHint: recommendedHint,
            updatedAt: now
        )
    }
}

private extension QueryGuidanceEngine {
    struct TextSource {
        let text: String
    }

    struct SignalSummary {
        var procedural = 0
        var reasoning = 0
        var decision = 0
        var exception = 0
        var control = 0
        var data = 0
        var reporting = 0
        var painPoint = 0
        var metric = 0
        var screenshotCount = 0
        var recentScreenshot: ScreenshotCapture?

        var isProceduralHeavy: Bool {
            procedural >= 2 && procedural > (reasoning + decision)
        }
    }

    static func buildSources(
        interviewSetup: InterviewSetup,
        utterances: [Utterance],
        notes: [BANote],
        tags: [InterviewTag],
        screenshots: [ScreenshotCapture]
    ) -> [TextSource] {
        var sources: [TextSource] = []

        if !interviewSetup.processArea.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sources.append(.init(text: interviewSetup.processArea))
        }
        if !interviewSetup.objective.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sources.append(.init(text: interviewSetup.objective))
        }
        if !interviewSetup.intervieweeRole.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sources.append(.init(text: interviewSetup.intervieweeRole))
        }

        sources.append(contentsOf: utterances.map {
            TextSource(text: $0.displayText)
        })
        sources.append(contentsOf: notes.map {
            TextSource(text: $0.text)
        })
        sources.append(contentsOf: tags.compactMap {
            guard let label = $0.label, !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return TextSource(text: $0.kind.displayLabel)
            }
            return TextSource(text: label)
        })
        sources.append(contentsOf: screenshots.compactMap {
            guard let label = $0.label, !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            return TextSource(text: label)
        })

        return sources
    }

    static func summarizeRecentSignals(
        utterances: [Utterance],
        notes: [BANote],
        screenshots: [ScreenshotCapture],
        now: Date
    ) -> SignalSummary {
        let recentUtterances = Array(utterances.suffix(8))
        let recentNotes = Array(notes.suffix(4))
        let recentScreenshots = screenshots.sorted { $0.timestamp > $1.timestamp }

        var summary = SignalSummary()
        summary.screenshotCount = recentScreenshots.count
        summary.recentScreenshot = recentScreenshots.first(where: {
            now.timeIntervalSince($0.timestamp) <= screenshotBiasWindow
        })

        let recentSources =
            recentUtterances.map { TextSource(text: $0.displayText) } +
            recentNotes.map { TextSource(text: $0.text) } +
            recentScreenshots.prefix(2).compactMap {
                guard let label = $0.label else { return nil }
                return TextSource(text: label)
            }

        for source in recentSources {
            let normalized = normalize(source.text)
            guard !normalized.isEmpty else { continue }

            summary.procedural += containsAny(normalized, proceduralKeywords) ? 1 : 0
            summary.reasoning += containsAny(normalized, purposeKeywords) ? 1 : 0
            summary.decision += containsAny(normalized, decisionKeywords) ? 1 : 0
            summary.exception += containsAny(normalized, exceptionKeywords) ? 1 : 0
            summary.control += containsAny(normalized, controlKeywords) ? 1 : 0
            summary.data += containsAny(normalized, dataKeywords) ? 1 : 0
            summary.reporting += containsAny(normalized, outputKeywords) ? 1 : 0
            summary.painPoint += containsAny(normalized, painPointKeywords) ? 1 : 0
            summary.metric += containsAny(normalized, metricKeywords) ? 1 : 0
        }

        return summary
    }

    static func detectMode(from signals: SignalSummary, hasTranscript: Bool) -> DetectedInterviewMode {
        if !hasTranscript {
            return .waitingForEvidence
        }
        if signals.recentScreenshot != nil {
            return .screenWalkthrough
        }
        if signals.reporting >= 2 {
            return .reportingReview
        }
        if signals.isProceduralHeavy {
            return .proceduralNarration
        }
        if signals.control >= 2 {
            return .controlDiscussion
        }
        if signals.exception >= 2 {
            return .exceptionDiscussion
        }
        if signals.decision + signals.reasoning >= 2 {
            return .decisionExplanation
        }
        return .proceduralNarration
    }

    static func recommendHint(
        interviewSetup: InterviewSetup,
        slotStates: [DomainSlotState],
        recentSignals: SignalSummary,
        detectedMode: DetectedInterviewMode
    ) -> GuidanceHint? {
        let missing = slotStates.filter { !$0.isFilled }.map(\.slot)
        guard !slotStates.isEmpty else { return nil }

        if let screenshot = recentSignals.recentScreenshot {
            let mode: QuestioningMode = missing.contains(.outputReport) ? .shiftToReporting : .shiftToDataNeeds
            return GuidanceHint(
                mode: mode,
                reason: screenshotReason(screenshot: screenshot, missing: missing),
                examplePrompts: prompts(for: mode, interviewSetup: interviewSetup),
                missingSlots: prioritizedMissingSlots(missing, preferred: [.outputReport, .dataNeeded, .decisionRule])
            )
        }

        if recentSignals.isProceduralHeavy && missing.contains(.processPurpose) {
            return GuidanceHint(
                mode: .shiftToWhy,
                reason: "The operator is describing steps, but the reason those steps exist is still thin.",
                examplePrompts: prompts(for: .shiftToWhy, interviewSetup: interviewSetup),
                missingSlots: prioritizedMissingSlots(missing, preferred: [.processPurpose, .trigger, .controlRationale])
            )
        }

        if recentSignals.isProceduralHeavy && missing.contains(.decisionRule) {
            return GuidanceHint(
                mode: .shiftToDecisionRules,
                reason: "You have actions in sequence, but not the conditions that decide which path to take.",
                examplePrompts: prompts(for: .shiftToDecisionRules, interviewSetup: interviewSetup),
                missingSlots: prioritizedMissingSlots(missing, preferred: [.decisionRule, .exceptionPath])
            )
        }

        if slotStates.contains(where: { $0.slot == .stepAction && $0.isFilled }) && missing.contains(.exceptionPath) {
            return GuidanceHint(
                mode: .shiftToExceptions,
                reason: "The main flow is forming, but the exception path is still missing.",
                examplePrompts: prompts(for: .shiftToExceptions, interviewSetup: interviewSetup),
                missingSlots: prioritizedMissingSlots(missing, preferred: [.exceptionPath, .controlRationale])
            )
        }

        if missing.contains(.controlRationale) && (recentSignals.control == 0 || detectedMode == .proceduralNarration) {
            return GuidanceHint(
                mode: .shiftToControls,
                reason: "Checks or manual steps are being mentioned without the control or risk rationale behind them.",
                examplePrompts: prompts(for: .shiftToControls, interviewSetup: interviewSetup),
                missingSlots: prioritizedMissingSlots(missing, preferred: [.controlRationale, .decisionRule])
            )
        }

        if missing.contains(.outputReport) && recentSignals.reporting > 0 {
            return GuidanceHint(
                mode: .shiftToReporting,
                reason: "A screen, report, or queue is in play, but the output and decisions from it are not yet grounded.",
                examplePrompts: prompts(for: .shiftToReporting, interviewSetup: interviewSetup),
                missingSlots: prioritizedMissingSlots(missing, preferred: [.outputReport, .dataNeeded, .metricSLA])
            )
        }

        if missing.contains(.dataNeeded) && (recentSignals.data > 0 || recentSignals.reporting > 0) {
            return GuidanceHint(
                mode: .shiftToDataNeeds,
                reason: "The workflow is moving forward, but the specific fields and values driving it are still underspecified.",
                examplePrompts: prompts(for: .shiftToDataNeeds, interviewSetup: interviewSetup),
                missingSlots: prioritizedMissingSlots(missing, preferred: [.dataNeeded, .decisionRule])
            )
        }

        guard let firstMissing = missing.first else { return nil }
        let fallbackMode = fallbackMode(for: firstMissing)
        return GuidanceHint(
            mode: fallbackMode,
            reason: fallbackReason(for: firstMissing),
            examplePrompts: prompts(for: fallbackMode, interviewSetup: interviewSetup),
            missingSlots: prioritizedMissingSlots(missing, preferred: [firstMissing])
        )
    }

    static func compactSnippet(_ text: String) -> String {
        let trimmed = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.count <= 90 { return trimmed }
        let end = trimmed.index(trimmed.startIndex, offsetBy: 87)
        return "\(trimmed[..<end])..."
    }

    static func normalize(_ text: String) -> String {
        text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains(where: { text.contains($0) })
    }

    static func prioritizedMissingSlots(_ missing: [DomainSlot], preferred: [DomainSlot]) -> [DomainSlot] {
        let ordered = preferred.filter { missing.contains($0) }
        let remaining = missing.filter { !ordered.contains($0) }
        return Array((ordered + remaining).prefix(3))
    }

    static func fallbackMode(for slot: DomainSlot) -> QuestioningMode {
        switch slot {
        case .processPurpose, .trigger, .actor, .systemMentioned:
            return .shiftToWhy
        case .stepAction, .decisionRule:
            return .shiftToDecisionRules
        case .exceptionPath:
            return .shiftToExceptions
        case .controlRationale:
            return .shiftToControls
        case .dataNeeded:
            return .shiftToDataNeeds
        case .outputReport, .metricSLA, .painPoint:
            return .shiftToReporting
        }
    }

    static func fallbackReason(for slot: DomainSlot) -> String {
        switch slot {
        case .processPurpose:
            return "The interview still needs the business purpose behind the process."
        case .trigger:
            return "The event that starts this process is not yet clearly grounded."
        case .actor:
            return "The owner or actor for the workflow is still ambiguous."
        case .systemMentioned:
            return "The systems or tools involved are not yet clearly named."
        case .stepAction:
            return "The concrete actions in the workflow still need more evidence."
        case .decisionRule:
            return "The conditions behind path changes or approvals are still missing."
        case .exceptionPath:
            return "The exception path has not been covered yet."
        case .controlRationale:
            return "The control or risk rationale behind the process is still missing."
        case .dataNeeded:
            return "The fields and values driving the work are still underspecified."
        case .outputReport:
            return "The outputs, reports, or downstream artifacts are still unclear."
        case .painPoint:
            return "The friction points in the current process still need more detail."
        case .metricSLA:
            return "The service levels, thresholds, or success metrics are still thin."
        }
    }

    static func screenshotReason(screenshot: ScreenshotCapture, missing: [DomainSlot]) -> String {
        if let label = screenshot.label, !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "A recent screenshot (\(compactSnippet(label))) gives you a good opening to ask what decisions and fields matter on screen."
        }
        if missing.contains(.outputReport) {
            return "A recent screenshot creates a good moment to ground what screen or report is being used and what it drives."
        }
        return "A recent screenshot creates a good moment to ask which fields, filters, or thresholds matter on screen."
    }

    static func prompts(for mode: QuestioningMode, interviewSetup: InterviewSetup) -> [String] {
        let processArea = interviewSetup.processArea.trimmingCharacters(in: .whitespacesAndNewlines)
        let subject = processArea.isEmpty ? "this process" : processArea

        switch mode {
        case .procedural:
            return [
                "What part of \(subject) is still unclear?",
                "What should we clarify before moving on?"
            ]
        case .shiftToWhy:
            return [
                "What is the reason this step exists in \(subject)?",
                "What risk or issue are you trying to catch here?",
                "If this step disappeared, what would break?"
            ]
        case .shiftToExceptions:
            return [
                "What usually goes wrong in this process?",
                "Which cases cannot follow the normal path?",
                "What do you do when the data is missing, late, or invalid?"
            ]
        case .shiftToDecisionRules:
            return [
                "What condition makes you choose path A vs B?",
                "Is there a threshold, status, or date that determines this?",
                "What makes a case eligible to continue?"
            ]
        case .shiftToControls:
            return [
                "Why does this check exist?",
                "What happens if it is skipped or delayed?",
                "Who is accountable for this control?"
            ]
        case .shiftToDataNeeds:
            return [
                "Which fields matter most to complete this step?",
                "What data is often missing or unreliable here?",
                "Which value drives the next action?"
            ]
        case .shiftToReporting:
            return [
                "What decision are you making from this screen or report?",
                "Which columns matter most and why?",
                "What is missing from this view that makes you open another tool?"
            ]
        case .screenWalkthrough:
            return [
                "What screen is this and when do you use it?",
                "Which fields on this screen change your next step?",
                "What do you still need to check outside this screen?"
            ]
        }
    }

    static let screenshotBiasWindow: TimeInterval = 120

    static let purposeKeywords = [
        "because", "so that", "in order to", "reason", "purpose", "goal", "trying to", "we need to"
    ]
    static let triggerKeywords = [
        "when", "once", "after", "before", "each day", "every day", "comes in", "received", "trigger"
    ]
    static let actorKeywords = [
        "team", "analyst", "operator", "supervisor", "owner", "desk", "client service", "ops"
    ]
    static let systemKeywords = [
        "system", "application", "tool", "platform", "portal", "dashboard", "queue", "excel", "screen"
    ]
    static let actionKeywords = [
        "review", "check", "open", "click", "match", "reconcile", "send", "update", "move", "approve",
        "process", "submit", "enter", "book", "confirm", "escalate", "run"
    ]
    static let proceduralKeywords = [
        "first", "then", "next", "after that", "afterwards", "finally", "start by", "we go to", "i open"
    ] + actionKeywords
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
