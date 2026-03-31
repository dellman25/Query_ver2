import XCTest
@testable import OpenOatsKit

final class QuerySummaryEngineTests: XCTestCase {
    func testGenerateSummaryBuildsEvidenceBackedFactsAndDrafts() {
        let start = Date(timeIntervalSince1970: 1_700_100_000)
        let transcript = [
            SessionRecord(
                speaker: .them,
                text: "First I open the fails queue and review each case.",
                timestamp: start
            ),
            SessionRecord(
                speaker: .them,
                text: "If the amount is above 1 million we escalate it for supervisor approval.",
                timestamp: start.addingTimeInterval(30)
            ),
            SessionRecord(
                speaker: .them,
                text: "If the account ID is missing it fails and goes to a manual queue.",
                timestamp: start.addingTimeInterval(60)
            ),
            SessionRecord(
                speaker: .them,
                text: "We track same-day SLA breaches on the dashboard.",
                timestamp: start.addingTimeInterval(90)
            ),
        ]
        let notes = [
            BANote(
                text: "Manual workaround when account ID is missing.",
                timestamp: start.addingTimeInterval(65),
                tags: [.painPoint]
            ),
            BANote(
                text: "Need to confirm who can override the threshold?",
                timestamp: start.addingTimeInterval(95),
                tags: [.openQuestion]
            ),
        ]
        let tags = [
            InterviewTag(kind: .businessRule, timestamp: start.addingTimeInterval(30), label: "Escalate above 1 million"),
            InterviewTag(kind: .control, timestamp: start.addingTimeInterval(31), label: "Supervisor approval"),
            InterviewTag(kind: .dataField, timestamp: start.addingTimeInterval(61), label: "Account ID"),
        ]
        let screenshots = [
            ScreenshotCapture(
                timestamp: start.addingTimeInterval(92),
                relativePath: "screenshots/fails-dashboard.png",
                label: "Daily fails dashboard"
            )
        ]

        let summary = QuerySummaryEngine.generate(
            context: .init(
                sessionID: "session_test",
                title: "Fails Interview",
                startedAt: start,
                interviewSetup: InterviewSetup(
                    processArea: "Fails Management",
                    intervieweeRole: "Settlement Analyst",
                    objective: "Understand why failed trades are escalated."
                )
            ),
            transcript: transcript,
            notes: notes,
            tags: tags,
            screenshots: screenshots,
            generatedAt: start.addingTimeInterval(120)
        )

        XCTAssertTrue(summary.extractedFacts.contains { $0.kind == .businessRule && !$0.evidence.isEmpty })
        XCTAssertTrue(summary.extractedFacts.contains { $0.kind == .exception && !$0.evidence.isEmpty })
        XCTAssertTrue(summary.extractedFacts.contains { $0.kind == .control && !$0.evidence.isEmpty })
        XCTAssertTrue(summary.extractedFacts.contains { $0.kind == .dataElement && !$0.evidence.isEmpty })
        XCTAssertTrue(summary.extractedFacts.contains { $0.kind == .metric && !$0.evidence.isEmpty })
        XCTAssertTrue(summary.extractedFacts.contains { $0.kind == .painPoint && !$0.evidence.isEmpty })
        XCTAssertTrue(summary.extractedFacts.contains { $0.kind == .openQuestion && !$0.evidence.isEmpty })
        XCTAssertTrue(summary.extractedFacts.contains { $0.kind == .requirementDraft && $0.isInferred })
        XCTAssertTrue(summary.openQuestions.contains(where: { $0.contains("override the threshold") }))
        XCTAssertFalse(summary.coverageSnapshot.isEmpty)
    }

    func testSummaryMarkdownIncludesEvidenceSections() {
        let start = Date(timeIntervalSince1970: 1_700_200_000)
        let summary = QuerySummaryEngine.generate(
            context: .init(
                sessionID: "session_markdown",
                title: "Ops Interview",
                startedAt: start,
                interviewSetup: InterviewSetup(
                    processArea: "Reconciliation",
                    intervieweeRole: "Ops Analyst",
                    objective: "Capture controls and exception paths."
                )
            ),
            transcript: [
                SessionRecord(
                    speaker: .them,
                    text: "If the trade breaks we reconcile it manually and send it for approval.",
                    timestamp: start
                )
            ],
            notes: [
                BANote(text: "Need to clarify who signs off the exception?", timestamp: start.addingTimeInterval(15))
            ],
            tags: [],
            screenshots: [],
            generatedAt: start.addingTimeInterval(30)
        )

        XCTAssertTrue(summary.markdown.contains("## Session Metadata"))
        XCTAssertTrue(summary.markdown.contains("## Process Understanding"))
        XCTAssertTrue(summary.markdown.contains("## Coverage Snapshot"))
        XCTAssertTrue(summary.markdown.contains("## Draft Requirements"))
        XCTAssertTrue(summary.markdown.contains("## Evidence References"))
        XCTAssertTrue(summary.markdown.contains("Transcript"))
    }

    func testRepositoryExportsSummaryMarkdown() async throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let exportDir = tempRoot.appendingPathComponent("exports", isDirectory: true)
        let repository = SessionRepository(rootDirectory: tempRoot)
        let start = Date(timeIntervalSince1970: 1_700_300_000)

        await repository.seedSession(
            id: "session_export",
            records: [
                SessionRecord(
                    speaker: .them,
                    text: "I review the queue every morning.",
                    timestamp: start
                )
            ],
            startedAt: start,
            title: "Export Session"
        )
        await repository.setNotesFolderPath(exportDir)

        let summary = QuerySummaryEngine.generate(
            context: .init(
                sessionID: "session_export",
                title: "Export Session",
                startedAt: start,
                interviewSetup: InterviewSetup(processArea: "Queue Review", intervieweeRole: "Analyst")
            ),
            transcript: [
                SessionRecord(
                    speaker: .them,
                    text: "I review the queue every morning.",
                    timestamp: start
                )
            ],
            notes: [],
            tags: [],
            screenshots: []
        )
        await repository.saveSummaryArtifact(sessionID: "session_export", summary: summary)

        let url = await repository.exportSummaryMarkdown(sessionID: "session_export")

        let resolvedURL = try XCTUnwrap(url)
        let content = try String(contentsOf: resolvedURL, encoding: .utf8)
        XCTAssertTrue(content.contains("# Export Session"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: resolvedURL.path))
    }
}
