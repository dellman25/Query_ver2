import Foundation

// MARK: - Interview Tag

enum InterviewTagKind: String, Codable, Sendable, CaseIterable, Identifiable {
    case businessRule = "business_rule"
    case exception
    case control
    case dataField = "data_field"
    case metric
    case painPoint = "pain_point"
    case openQuestion = "open_question"

    var id: String { rawValue }

    var displayLabel: String {
        switch self {
        case .businessRule: return "Business Rule"
        case .exception: return "Exception"
        case .control: return "Control"
        case .dataField: return "Data Field"
        case .metric: return "Metric"
        case .painPoint: return "Pain Point"
        case .openQuestion: return "Open Question"
        }
    }

    var systemImage: String {
        switch self {
        case .businessRule: return "checkmark.shield"
        case .exception: return "exclamationmark.triangle"
        case .control: return "lock.shield"
        case .dataField: return "tablecells"
        case .metric: return "chart.bar"
        case .painPoint: return "bolt"
        case .openQuestion: return "questionmark.circle"
        }
    }
}

struct InterviewTag: Identifiable, Codable, Sendable {
    let id: UUID
    let kind: InterviewTagKind
    let timestamp: Date
    /// Optional transcript segment ID this tag is linked to.
    let transcriptSegmentID: UUID?
    /// Optional BA note ID this tag is linked to.
    let noteID: UUID?
    /// Freeform label if the BA wants to annotate the tag.
    var label: String?

    init(
        kind: InterviewTagKind,
        timestamp: Date = .now,
        transcriptSegmentID: UUID? = nil,
        noteID: UUID? = nil,
        label: String? = nil
    ) {
        self.id = UUID()
        self.kind = kind
        self.timestamp = timestamp
        self.transcriptSegmentID = transcriptSegmentID
        self.noteID = noteID
        self.label = label
    }
}

// MARK: - BA Note

struct BANote: Identifiable, Codable, Sendable {
    let id: UUID
    var text: String
    let timestamp: Date
    var tags: [InterviewTagKind]

    init(
        text: String,
        timestamp: Date = .now,
        tags: [InterviewTagKind] = []
    ) {
        self.id = UUID()
        self.text = text
        self.timestamp = timestamp
        self.tags = tags
    }
}

// MARK: - Screenshot Capture

struct ScreenshotCapture: Identifiable, Codable, Sendable {
    let id: UUID
    let timestamp: Date
    /// Relative path within the session folder (e.g. "screenshots/001.png").
    let relativePath: String
    /// Optional user-supplied label (e.g. "daily fails dashboard").
    var label: String?
    /// The nearest transcript utterance ID at capture time.
    let nearestUtteranceID: UUID?

    init(
        timestamp: Date = .now,
        relativePath: String,
        label: String? = nil,
        nearestUtteranceID: UUID? = nil
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.relativePath = relativePath
        self.label = label
        self.nearestUtteranceID = nearestUtteranceID
    }
}

// MARK: - Evidence Reference

/// Links an extracted fact back to its source material.
struct EvidenceReference: Codable, Sendable {
    enum SourceKind: String, Codable, Sendable {
        case transcript
        case note
        case screenshot
        case tag
    }

    let sourceKind: SourceKind
    let sourceID: UUID?
    let timestamp: Date?
    let snippet: String?
    /// Whether this was explicitly tagged by the BA or inferred by the system.
    let isExplicit: Bool
}

// MARK: - Extracted Fact

enum ExtractedFactKind: String, Codable, Sendable, CaseIterable {
    case processStep = "process_step"
    case businessRule = "business_rule"
    case exception
    case control
    case dataElement = "data_element"
    case painPoint = "pain_point"
    case metric
    case openQuestion = "open_question"
    case requirementDraft = "requirement_draft"

    var displayLabel: String {
        switch self {
        case .processStep: return "Process Step"
        case .businessRule: return "Business Rule"
        case .exception: return "Exception"
        case .control: return "Control"
        case .dataElement: return "Data Element"
        case .painPoint: return "Pain Point"
        case .metric: return "Metric"
        case .openQuestion: return "Open Question"
        case .requirementDraft: return "Requirement Draft"
        }
    }
}

struct ExtractedFact: Identifiable, Codable, Sendable {
    let id: UUID
    let kind: ExtractedFactKind
    let text: String
    let evidence: [EvidenceReference]
    /// Whether this was directly grounded in source material or inferred.
    let isInferred: Bool

    init(
        kind: ExtractedFactKind,
        text: String,
        evidence: [EvidenceReference] = [],
        isInferred: Bool = false
    ) {
        self.id = UUID()
        self.kind = kind
        self.text = text
        self.evidence = evidence
        self.isInferred = isInferred
    }
}

extension ExtractedFact {
    var statusLabel: String {
        isInferred ? "Inferred" : "Explicit"
    }
}

// MARK: - Domain Slot Tracking

/// Tracks which requirement dimensions have been captured during the interview.
enum DomainSlot: String, Codable, Sendable, CaseIterable {
    case processPurpose = "process_purpose"
    case trigger
    case actor
    case systemMentioned = "system_mentioned"
    case stepAction = "step_action"
    case decisionRule = "decision_rule"
    case exceptionPath = "exception_path"
    case controlRationale = "control_rationale"
    case dataNeeded = "data_needed"
    case outputReport = "output_report"
    case painPoint = "pain_point"
    case metricSLA = "metric_sla"

    var displayLabel: String {
        switch self {
        case .processPurpose: return "Purpose"
        case .trigger: return "Trigger"
        case .actor: return "Actor"
        case .systemMentioned: return "System"
        case .stepAction: return "Steps"
        case .decisionRule: return "Decision Logic"
        case .exceptionPath: return "Exceptions"
        case .controlRationale: return "Controls"
        case .dataNeeded: return "Data Fields"
        case .outputReport: return "Outputs"
        case .painPoint: return "Pain Points"
        case .metricSLA: return "Metrics"
        }
    }
}

/// Current fill state for a domain slot.
struct DomainSlotState: Codable, Sendable {
    let slot: DomainSlot
    var isFilled: Bool
    var snippets: [String]

    init(slot: DomainSlot, isFilled: Bool = false, snippets: [String] = []) {
        self.slot = slot
        self.isFilled = isFilled
        self.snippets = snippets
    }
}

// MARK: - Interview Guidance

enum DetectedInterviewMode: String, Codable, Sendable, CaseIterable {
    case waitingForEvidence = "waiting_for_evidence"
    case proceduralNarration = "procedural_narration"
    case decisionExplanation = "decision_explanation"
    case exceptionDiscussion = "exception_discussion"
    case controlDiscussion = "control_discussion"
    case screenWalkthrough = "screen_walkthrough"
    case reportingReview = "reporting_review"

    var displayLabel: String {
        switch self {
        case .waitingForEvidence: return "Waiting for Evidence"
        case .proceduralNarration: return "Procedural Narration"
        case .decisionExplanation: return "Decision Explanation"
        case .exceptionDiscussion: return "Exception Discussion"
        case .controlDiscussion: return "Control Discussion"
        case .screenWalkthrough: return "Screen Walkthrough"
        case .reportingReview: return "Reporting Review"
        }
    }
}

/// The recommended questioning mode shift.
enum QuestioningMode: String, Codable, Sendable, CaseIterable {
    case procedural
    case shiftToWhy = "shift_to_why"
    case shiftToExceptions = "shift_to_exceptions"
    case shiftToDecisionRules = "shift_to_decision_rules"
    case shiftToControls = "shift_to_controls"
    case shiftToDataNeeds = "shift_to_data_needs"
    case shiftToReporting = "shift_to_reporting"
    case screenWalkthrough = "screen_walkthrough"

    var displayLabel: String {
        switch self {
        case .procedural: return "Procedural"
        case .shiftToWhy: return "Shift to Why"
        case .shiftToExceptions: return "Shift to Exceptions"
        case .shiftToDecisionRules: return "Shift to Decision Rules"
        case .shiftToControls: return "Shift to Controls"
        case .shiftToDataNeeds: return "Shift to Data Needs"
        case .shiftToReporting: return "Shift to Reporting"
        case .screenWalkthrough: return "Screen Walkthrough"
        }
    }
}

struct GuidanceSnapshot: Sendable {
    let slotStates: [DomainSlotState]
    let detectedMode: DetectedInterviewMode
    let recommendedHint: GuidanceHint?
    let updatedAt: Date

    var filledSlots: [DomainSlotState] {
        slotStates.filter(\.isFilled)
    }

    var missingSlots: [DomainSlotState] {
        slotStates.filter { !$0.isFilled }
    }

    func state(for slot: DomainSlot) -> DomainSlotState {
        slotStates.first(where: { $0.slot == slot }) ?? DomainSlotState(slot: slot)
    }
}

struct GuidanceHint: Identifiable, Sendable {
    let id: UUID
    let mode: QuestioningMode
    let reason: String
    let examplePrompts: [String]
    let missingSlots: [DomainSlot]
    let timestamp: Date

    init(
        mode: QuestioningMode,
        reason: String,
        examplePrompts: [String] = [],
        missingSlots: [DomainSlot] = [],
        timestamp: Date = .now
    ) {
        self.id = UUID()
        self.mode = mode
        self.reason = reason
        self.examplePrompts = examplePrompts
        self.missingSlots = missingSlots
        self.timestamp = timestamp
    }
}

// MARK: - Summary Artifact

struct SummaryArtifact: Codable, Sendable {
    let generatedAt: Date
    let sessionSummary: String
    let processUnderstanding: String
    let extractedFacts: [ExtractedFact]
    let openQuestions: [String]
    let coverageSnapshot: [DomainSlotState]
    let markdown: String
}

extension SummaryArtifact {
    var groupedFacts: [(kind: ExtractedFactKind, facts: [ExtractedFact])] {
        ExtractedFactKind.allCases.compactMap { kind in
            let matches = extractedFacts.filter { $0.kind == kind }
            guard !matches.isEmpty else { return nil }
            return (kind, matches)
        }
    }

    var requirementDrafts: [ExtractedFact] {
        extractedFacts.filter { $0.kind == .requirementDraft }
    }

    var evidenceCount: Int {
        extractedFacts.reduce(0) { $0 + $1.evidence.count }
    }

    var missingCoverage: [DomainSlotState] {
        coverageSnapshot.filter { !$0.isFilled }
    }

    var filledCoverage: [DomainSlotState] {
        coverageSnapshot.filter(\.isFilled)
    }
}

// MARK: - Interview Session Setup

/// Metadata specific to a Query interview session, persisted alongside SessionMetadata.
struct InterviewSetup: Codable, Sendable {
    var processArea: String
    var intervieweeRole: String
    var objective: String

    init(processArea: String = "", intervieweeRole: String = "", objective: String = "") {
        self.processArea = processArea
        self.intervieweeRole = intervieweeRole
        self.objective = objective
    }
}

// MARK: - Timeline Event

/// Unified timeline item for display.
enum TimelineEvent: Identifiable, Sendable {
    case transcript(Utterance)
    case note(BANote)
    case tag(InterviewTag)
    case screenshot(ScreenshotCapture)

    var id: UUID {
        switch self {
        case .transcript(let u): return u.id
        case .note(let n): return n.id
        case .tag(let t): return t.id
        case .screenshot(let s): return s.id
        }
    }

    var timestamp: Date {
        switch self {
        case .transcript(let u): return u.timestamp
        case .note(let n): return n.timestamp
        case .tag(let t): return t.timestamp
        case .screenshot(let s): return s.timestamp
        }
    }
}
