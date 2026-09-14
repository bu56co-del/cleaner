import XCTest
@testable import PawlyCore

final class CommandRunnerTests: XCTestCase {
    let shell = URL(fileURLWithPath: "/bin/bash")
    func testArgumentsAreNotInterpolatedAndStreamsDoNotDeadlock() {
        let text = "spaces ' 中文 $(touch /tmp/should-not-exist) `echo bad`"
        let result = CommandRunner().run(shell, arguments: ["-c", "printf '%s' \"$1\"; for ((i=0;i<2000;i++)); do printf 'warning\\n' >&2; done", "test", text], timeout: 5)
        XCTAssertTrue(result.success, result.error)
        XCTAssertEqual(String(decoding: result.data, as: UTF8.self), text)
    }
    func testNonzeroExitDiscardsPartialOutput() {
        let result = CommandRunner().run(shell, arguments: ["-c", "printf '{\"partial\":true}'; printf 'specific failure' >&2; exit 7"])
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.status, 7)
        XCTAssertTrue(result.data.isEmpty)
        XCTAssertEqual(result.error, "specific failure")
    }
    func testTimeoutTerminatesProducerAndDiscardsOutput() {
        let began = Date()
        let result = CommandRunner().run(shell, arguments: ["-c", "printf 'unfinished'; sleep 30 & wait"], timeout: 0.15)
        XCTAssertTrue(result.timedOut)
        XCTAssertFalse(result.success)
        XCTAssertTrue(result.data.isEmpty)
        XCTAssertLessThan(Date().timeIntervalSince(began), 3)
    }
    func testCancellationOfRunningCommandIsBounded() {
        let token = CancellationToken()
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.15) { token.cancel() }
        let began = Date()
        let result = CommandRunner().run(shell, arguments: ["-c", "trap '' TERM; sleep 30 & wait"], timeout: 10, token: token)
        XCTAssertTrue(result.cancelled)
        XCTAssertFalse(result.timedOut)
        XCTAssertLessThan(Date().timeIntervalSince(began), 3)
    }
    func testCancelledCommandDoesNotStart() {
        let token = CancellationToken(); token.cancel()
        let result = CommandRunner().run(shell, arguments: ["-c", "printf started"], token: token)
        XCTAssertTrue(result.cancelled); XCTAssertTrue(result.data.isEmpty)
    }
    func testJSONMissingValuesRemainUnknown() throws {
        let result = try JSONDecoder().decode(JSONValue.self, from: Data("{\"cpu\":{\"usage\":0},\"batteries\":null}".utf8))
        XCTAssertEqual(result["cpu"]["usage"].number, 0)
        XCTAssertNil(result["cpu"]["load1"].number)
        XCTAssertNil(result["thermal"]["cpu_temp"].number)
        XCTAssertEqual(result["batteries"].array, [])
    }
    func testOperationArgumentsKeepExactTargetAsSingleArgument() {
        let path = "/Applications/Special ' 中文 App.app"
        let request = OperationRequest(action: .uninstall, target: path, identity: "1:2:3")
        XCTAssertEqual(request.arguments, ["uninstall", "preview", path, "1:2:3"])
    }
}
