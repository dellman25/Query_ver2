import Foundation

private struct AgentDebugLogEntry: Encodable {
    let sessionId: String
    let runId: String
    let hypothesisId: String
    let location: String
    let message: String
    let data: [String: String]
    let timestamp: Int64
}

private let agentDebugLogPath = "/Users/darwinarifin/Documents/Query/OpenOats/.cursor/debug-08396d.log"
private let agentDebugSessionID = "08396d"

func agentDebugLog(
    runId: String,
    hypothesisId: String,
    location: String,
    message: String,
    data: [String: String] = [:]
) {
    let entry = AgentDebugLogEntry(
        sessionId: agentDebugSessionID,
        runId: runId,
        hypothesisId: hypothesisId,
        location: location,
        message: message,
        data: data,
        timestamp: Int64(Date().timeIntervalSince1970 * 1000)
    )

    guard let encoded = try? JSONEncoder().encode(entry) else { return }
    var line = encoded
    line.append(0x0A)

    if let handle = FileHandle(forWritingAtPath: agentDebugLogPath) {
        try? handle.seekToEnd()
        try? handle.write(contentsOf: line)
        try? handle.close()
    } else {
        FileManager.default.createFile(atPath: agentDebugLogPath, contents: line)
    }
}
