import XCTest
@testable import PawlyCore

final class ProjectTests: XCTestCase {
    var home: URL!
    var project: URL!
    var engine: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Bridge") }
    override func setUpWithError() throws {
        home = URL(fileURLWithPath: "/private/tmp").appendingPathComponent("pawly-project-test-" + UUID().uuidString)
        project = home.appendingPathComponent("Projects/Cat app")
        try FileManager.default.createDirectory(at: project.appendingPathComponent("dist"), withIntermediateDirectories: true)
        try Data("{\"name\":\"pawly-fixture\"}".utf8).write(to: project.appendingPathComponent("package.json"))
        try Data(repeating: 42, count: 8192).write(to: project.appendingPathComponent("dist/generated.js"))
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: home) } // Only this test's generated directory.
    func testProjectInventoryIncludesRecentArtifactsButDoesNotSelectOrDelete() throws {
        let report = try ProjectClient(engine: engine, home: home).scan(location: project.path, token: CancellationToken())
        XCTAssertTrue(report.complete, report.outcome)
        XCTAssertEqual(report.items.count, 1)
        let item = try XCTUnwrap(report.items.first)
        XCTAssertEqual(item.path, project.appendingPathComponent("dist").path)
        XCTAssertEqual(item.activity, "recent")
        XCTAssertFalse(item.unknownSize)
        XCTAssertGreaterThanOrEqual(item.bytes, 8192)
        XCTAssertFalse(item.targetIdentity.isEmpty)
        XCTAssertEqual(item.reviewRoot(home: home), project.path)
        XCTAssertEqual(try Data(contentsOf: project.appendingPathComponent("dist/generated.js")), Data(repeating: 42, count: 8192))
        XCTAssertFalse(FileManager.default.fileExists(atPath: home.appendingPathComponent(".config/mole/purge_paths").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: home.appendingPathComponent(".cache/mole/purge_stats").path))
    }
    func testExactSelectedPurgePreservesUnselectedAndSourceFiles() throws {
        try FileManager.default.createDirectory(at: project.appendingPathComponent("build"), withIntermediateDirectories: true)
        try Data(repeating: 77, count: 4096).write(to: project.appendingPathComponent("build/keep.js"))
        let client = ProjectClient(engine: engine, home: home)
        let report = try client.scan(location: project.path, token: CancellationToken())
        XCTAssertEqual(report.items.count, 2)
        let item = try XCTUnwrap(report.items.first { $0.path.hasSuffix("/dist") })
        let preview = try client.perform([item], preview: true, token: CancellationToken())
        XCTAssertTrue(preview.completed(1), preview.outcome)
        XCTAssertTrue(FileManager.default.fileExists(atPath: item.path))
        let result = try client.perform([item], preview: false, token: CancellationToken())
        XCTAssertTrue(result.completed(1), result.outcome)
        XCTAssertFalse(FileManager.default.fileExists(atPath: item.path))
        XCTAssertEqual(try Data(contentsOf: project.appendingPathComponent("build/keep.js")), Data(repeating: 77, count: 4096))
        XCTAssertTrue(FileManager.default.fileExists(atPath: project.appendingPathComponent("package.json").path))
    }
    func testPurgeRejectsReplacedTargetAndDuplicateSelectionBeforeAnyRemoval() throws {
        let client = ProjectClient(engine: engine, home: home)
        let item = try XCTUnwrap(try client.scan(location: project.path, token: CancellationToken()).items.first)
        XCTAssertThrowsError(try client.perform([item, item], preview: false, token: CancellationToken()))
        try FileManager.default.moveItem(at: project.appendingPathComponent("dist"), to: project.appendingPathComponent("saved"))
        try FileManager.default.createDirectory(at: project.appendingPathComponent("dist"), withIntermediateDirectories: true)
        try Data(repeating: 99, count: 8192).write(to: project.appendingPathComponent("dist/generated.js"))
        XCTAssertThrowsError(try client.perform([item], preview: false, token: CancellationToken()))
        XCTAssertEqual(try Data(contentsOf: project.appendingPathComponent("dist/generated.js")), Data(repeating: 99, count: 8192))
        XCTAssertEqual(try Data(contentsOf: project.appendingPathComponent("saved/generated.js")), Data(repeating: 42, count: 8192))
    }
    func testPurgeRejectsChangedScanRootAndNewWhitelist() throws {
        let client = ProjectClient(engine: engine, home: home)
        let item = try XCTUnwrap(try client.scan(location: project.path, token: CancellationToken()).items.first)
        let config = home.appendingPathComponent(".config/mole")
        try FileManager.default.createDirectory(at: config, withIntermediateDirectories: true)
        try Data((item.path + "\n").utf8).write(to: config.appendingPathComponent("whitelist"))
        XCTAssertThrowsError(try client.perform([item], preview: false, token: CancellationToken()))
        XCTAssertTrue(FileManager.default.fileExists(atPath: item.path))
        // Move the original artifact into a replacement project root: the target
        // inode survives, but the reviewed root identity must still refuse it.
        let savedProject = project.appendingPathExtension("saved")
        try FileManager.default.moveItem(at: project, to: savedProject)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: savedProject.appendingPathComponent("dist"), to: project.appendingPathComponent("dist"))
        try Data("{}".utf8).write(to: project.appendingPathComponent("package.json"))
        try Data().write(to: config.appendingPathComponent("whitelist"))
        XCTAssertThrowsError(try client.perform([item], preview: false, token: CancellationToken()))
        XCTAssertTrue(FileManager.default.fileExists(atPath: item.path))
    }
    func testReviewScopeNeverExpandsToAnAncestorOrSimilarPrefix() throws {
        func item(_ label: String) throws -> ProjectArtifact {
            let data = try JSONSerialization.data(withJSONObject: ["path": "/chosen/app/dist", "project": label, "artifact": "dist", "bytes": 1, "unknownSize": false, "activity": "old", "age": "20d", "cloud": false, "targetIdentity": "1", "parentIdentity": "2", "scanRoot": "/chosen/app", "rootBindings": ["/chosen/app", "1", "2", "/chosen/app", "1", "2"]])
            return try JSONDecoder().decode(ProjectArtifact.self, from: data)
        }
        for label in ["/chosen", "/chosen/application", "/elsewhere", "/chosen/app/../other", "relative"] {
            XCTAssertEqual(try item(label).reviewRoot(home: home), "/chosen/app", label)
        }
        XCTAssertEqual(try item("/chosen/app/child").reviewRoot(home: home), "/chosen/app/child")
        XCTAssertEqual(try item("[cloud] /chosen/app").reviewRoot(home: home), "/chosen/app")
    }
    func testProjectInventoryProtectsWhitelistedArtifactAndRejectsMissingRoot() throws {
        let config = home.appendingPathComponent(".config/mole")
        try FileManager.default.createDirectory(at: config, withIntermediateDirectories: true)
        try Data((project.appendingPathComponent("dist").path + "\n").utf8).write(to: config.appendingPathComponent("whitelist"))
        let client = ProjectClient(engine: engine, home: home)
        let report = try client.scan(location: project.path, token: CancellationToken())
        XCTAssertTrue(report.complete)
        XCTAssertTrue(report.items.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: project.appendingPathComponent("dist/generated.js").path))
        XCTAssertThrowsError(try client.scan(location: project.appendingPathComponent("missing").path, token: CancellationToken()))
    }
}
