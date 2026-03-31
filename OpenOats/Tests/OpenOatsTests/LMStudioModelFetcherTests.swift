import XCTest
@testable import OpenOatsKit

final class LMStudioModelFetcherTests: XCTestCase {
    func testModelsURLBuildsFromBareHost() {
        let url = LMStudioModelFetcher.modelsURL(from: "http://localhost:1234")
        XCTAssertEqual(url?.absoluteString, "http://localhost:1234/v1/models")
    }

    func testModelsURLStripsV1Suffixes() {
        let fromV1 = LMStudioModelFetcher.modelsURL(from: "http://localhost:1234/v1")
        let fromModels = LMStudioModelFetcher.modelsURL(from: "http://localhost:1234/v1/models")

        XCTAssertEqual(fromV1?.absoluteString, "http://localhost:1234/v1/models")
        XCTAssertEqual(fromModels?.absoluteString, "http://localhost:1234/v1/models")
    }

    func testModelsURLTrimsWhitespaceAndTrailingSlash() {
        let url = LMStudioModelFetcher.modelsURL(from: "  http://localhost:1234/  ")
        XCTAssertEqual(url?.absoluteString, "http://localhost:1234/v1/models")
    }

    func testParseModelNamesReturnsSortedUniqueIDs() {
        let payload = """
        {
          "data": [
            { "id": "qwen-embed" },
            { "id": "llama-3.1-8b" },
            { "id": "qwen-embed" }
          ]
        }
        """

        let modelNames = LMStudioModelFetcher.parseModelNames(from: Data(payload.utf8))

        XCTAssertEqual(modelNames, ["llama-3.1-8b", "qwen-embed"])
    }

    func testParseModelNamesReturnsNilForUnexpectedPayload() {
        let payload = #"{"object":"list","items":[]}"#
        XCTAssertNil(LMStudioModelFetcher.parseModelNames(from: Data(payload.utf8)))
    }
}
