import XCTest
@testable import OpenOatsKit

final class QueryGuidanceEngineTests: XCTestCase {
    func testProceduralNarrationSuggestsShiftToWhy() {
        let now = Date()
        let utterances = [
            Utterance(
                text: "First I open the queue, then I check each item and move it to the settlement batch.",
                speaker: .them,
                timestamp: now.addingTimeInterval(-40)
            ),
            Utterance(
                text: "Next I update the status and send it for approval.",
                speaker: .them,
                timestamp: now.addingTimeInterval(-20)
            ),
        ]

        let snapshot = QueryGuidanceEngine.analyze(
            interviewSetup: InterviewSetup(),
            utterances: utterances,
            notes: [],
            tags: [],
            screenshots: [],
            now: now
        )

        XCTAssertEqual(snapshot.detectedMode, .proceduralNarration)
        XCTAssertEqual(snapshot.recommendedHint?.mode, .shiftToWhy)
        XCTAssertTrue(snapshot.state(for: .stepAction).isFilled)
        XCTAssertFalse(snapshot.state(for: .processPurpose).isFilled)
    }

    func testRecentScreenshotBiasesTowardScreenBasedGuidance() {
        let now = Date()
        let screenshot = ScreenshotCapture(
            timestamp: now.addingTimeInterval(-30),
            relativePath: "screenshots/example.png"
        )

        let snapshot = QueryGuidanceEngine.analyze(
            interviewSetup: InterviewSetup(processArea: "Fails Management", intervieweeRole: "Ops Analyst"),
            utterances: [
                Utterance(text: "This is what I look at every morning.", speaker: .them, timestamp: now.addingTimeInterval(-45))
            ],
            notes: [],
            tags: [],
            screenshots: [screenshot],
            now: now
        )

        XCTAssertEqual(snapshot.detectedMode, .screenWalkthrough)
        XCTAssertEqual(snapshot.recommendedHint?.mode, .shiftToReporting)
        XCTAssertTrue(snapshot.recommendedHint?.reason.contains("screenshot") ?? false)
    }

    func testTagsAndNotesFillDomainCoverageSlots() {
        let now = Date()
        let snapshot = QueryGuidanceEngine.analyze(
            interviewSetup: InterviewSetup(
                processArea: "Trade Settlement",
                intervieweeRole: "Settlement Analyst",
                objective: "Understand why failed trades are escalated."
            ),
            utterances: [
                Utterance(
                    text: "If the amount is above the threshold we escalate it, and errors go to a manual queue.",
                    speaker: .them,
                    timestamp: now.addingTimeInterval(-90)
                )
            ],
            notes: [
                BANote(
                    text: "Manual workaround when account ID is missing and backlog breaches SLA.",
                    timestamp: now.addingTimeInterval(-50),
                    tags: [.painPoint, .metric]
                )
            ],
            tags: [
                InterviewTag(kind: .businessRule, timestamp: now.addingTimeInterval(-80), label: "Escalate above threshold"),
                InterviewTag(kind: .exception, timestamp: now.addingTimeInterval(-70), label: "Missing account ID"),
                InterviewTag(kind: .control, timestamp: now.addingTimeInterval(-60), label: "Supervisor approval"),
                InterviewTag(kind: .dataField, timestamp: now.addingTimeInterval(-55), label: "Account ID"),
                InterviewTag(kind: .metric, timestamp: now.addingTimeInterval(-45), label: "Same-day SLA"),
                InterviewTag(kind: .painPoint, timestamp: now.addingTimeInterval(-40), label: "Manual queue")
            ],
            screenshots: [],
            now: now
        )

        XCTAssertTrue(snapshot.state(for: .actor).isFilled)
        XCTAssertTrue(snapshot.state(for: .processPurpose).isFilled)
        XCTAssertTrue(snapshot.state(for: .decisionRule).isFilled)
        XCTAssertTrue(snapshot.state(for: .exceptionPath).isFilled)
        XCTAssertTrue(snapshot.state(for: .controlRationale).isFilled)
        XCTAssertTrue(snapshot.state(for: .dataNeeded).isFilled)
        XCTAssertTrue(snapshot.state(for: .metricSLA).isFilled)
        XCTAssertTrue(snapshot.state(for: .painPoint).isFilled)
    }
}
