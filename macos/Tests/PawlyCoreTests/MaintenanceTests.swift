import XCTest
@testable import PawlyCore

final class MaintenanceTests: XCTestCase {
    var fixture: URL!
    var engine: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Bridge") }
    override func setUpWithError() throws {
        fixture = URL(fileURLWithPath: "/private/tmp").appendingPathComponent("pawly-maintenance-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: fixture.appendingPathComponent(".config/mole"), withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: fixture) } // Only this test's generated directory.
    func testCatalogAndPreviewHonorLegacyExclusionsWithoutWritingConfig() throws {
        let config = fixture.appendingPathComponent(".config/mole/whitelist_checks")
        try Data("cache_refresh\n".utf8).write(to: config)
        let client = MaintenanceClient(engine: engine, home: fixture)
        let tasks = try client.catalog(token: CancellationToken())
        XCTAssertEqual(tasks.count, 21)
        XCTAssertTrue(try XCTUnwrap(tasks.first { $0.id == "cache_refresh" }).excluded)
        let preview = try client.preview("cache_refresh", token: CancellationToken())
        XCTAssertEqual(preview.outcome, "skipped")
        XCTAssertTrue(preview.detail.contains("whitelisted"))
        XCTAssertEqual(try String(contentsOf: config, encoding: .utf8), "cache_refresh\n")
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.appendingPathComponent(".config/mole/whitelist_optimize").path))
    }
    func testUnknownTaskRefusesAndActualPreviewDoesNotWriteFinderPreferences() throws {
        let client = MaintenanceClient(engine: engine, home: fixture)
        XCTAssertThrowsError(try client.preview("cache_refresh; touch injected", token: CancellationToken()))
        let before = try FileManager.default.contentsOfDirectory(atPath: fixture.path)
        let preview = try client.preview("cache_refresh", token: CancellationToken())
        XCTAssertEqual(preview.id, "cache_refresh")
        XCTAssertEqual(preview.outcome, "applied")
        XCTAssertTrue(preview.detail.contains("QuickLook"))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: fixture.path), before)
    }
}
