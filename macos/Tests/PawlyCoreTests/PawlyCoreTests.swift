import XCTest
@testable import PawlyCore

final class PawlyCoreTests: XCTestCase {
    var fixture: URL!
    var home: URL!
    override func setUpWithError() throws {
        fixture = URL(fileURLWithPath: "/private/tmp", isDirectory: true).appendingPathComponent("pawly-test-" + UUID().uuidString)
        home = fixture.appendingPathComponent("home")
        for relative in ["Library/Caches", "Library/Logs", "Downloads", "Documents"] {
            try FileManager.default.createDirectory(at: home.appendingPathComponent(relative), withIntermediateDirectories: true)
        }
    }
    override func tearDownWithError() throws {
        if let fixture { try FileManager.default.removeItem(at: fixture) } // Only this test's unique fixture tree.
    }
    @discardableResult func file(_ relative: String, bytes: Int = 2048, ageDays: Double = 20) throws -> URL {
        let url = home.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 0x61, count: bytes).write(to: url)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-ageDays * 86400)], ofItemAtPath: url.path)
        return url
    }
    func item(_ url: URL, category: CleanupCategory) throws -> CleanupItem {
        CleanupItem(url: url, category: category, bytes: Int64(try Data(contentsOf: url).count), fileCount: 1,
                    identity: try FileIdentity.read(url), parentIdentity: try FileIdentity.read(url.deletingLastPathComponent()))
    }
    var bridge: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Bridge/pawly-bridge.sh")
    }

    func testScanIncludesOnlyReviewScopeAndNeverChangesFiles() throws {
        let cache = try file("Library/Caches/com.example.test/blob", bytes: 4096)
        let log = try file("Library/Logs/Archive/old.log")
        let installer = try file("Downloads/Old installer.dmg", bytes: 8192)
        let excluded = [
            try file("Documents/important.log"),
            try file("Downloads/fresh.dmg", ageDays: 1),
            try file("Downloads/photos.zip"),
            try file("Library/Logs/current.log", ageDays: 1),
            try file("Library/Caches/com.apple.finder/cache"),
            try file("Library/Caches/Codex/session"),
            try file("Library/Logs/mole/operations.log")
        ]
        let report = FileScanner(home: home).scan(token: CancellationToken())
        XCTAssertTrue(report.completed)
        XCTAssertEqual(Set(report.items.map(\.id)), Set([cache.deletingLastPathComponent().path, log.path, installer.path]))
        XCTAssertEqual(report.bytes, 14336)
        XCTAssertEqual(report.scannedCategories, Set(CleanupCategory.allCases))
        for url in excluded + [cache, log, installer] { XCTAssertTrue(FileManager.default.fileExists(atPath: url.path)) }
    }
    func testQuickCleanerCancellationStopsTheOwnedProducer() throws {
        let installer = try file("Downloads/cancelled.dmg")
        let fakeBridge = fixture.appendingPathComponent("waiting-bridge.sh")
        try Data("trap '' TERM\nprintf 'partial preview'\nsleep 30 & wait\n".utf8).write(to: fakeBridge)
        let token = CancellationToken()
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.15) { token.cancel() }
        let began = Date()
        let result = EngineClient(bridge: fakeBridge, home: home).perform(try item(installer, category: .installers), preview: true, token: token)
        XCTAssertFalse(result.success)
        XCTAssertLessThan(Date().timeIntervalSince(began), 3)
        XCTAssertTrue(FileManager.default.fileExists(atPath: installer.path))
    }
    func testSymlinkTargetsAndAncestorsCannotBecomeCandidates() throws {
        let document = try file("Documents/real.dmg")
        let link = home.appendingPathComponent("Downloads/link.dmg")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: document)
        XCTAssertFalse(PathPolicy.isCandidate(link, category: .installers, home: home))
        let cached = home.appendingPathComponent("Library/Caches/alias")
        try FileManager.default.createSymbolicLink(at: cached, withDestinationURL: home.appendingPathComponent("Documents"))
        XCTAssertFalse(PathPolicy.hasNoSymlinkComponents(cached.appendingPathComponent("real.dmg")))
        XCTAssertTrue(FileScanner(home: home).scan(token: CancellationToken()).items.isEmpty)
    }
    func testNestedSymlinkExcludesWholeCacheMeasurement() throws {
        let cache = try file("Library/Caches/example/blob")
        let target = try file("Documents/secret")
        try FileManager.default.createSymbolicLink(at: cache.deletingLastPathComponent().appendingPathComponent("escape"), withDestinationURL: target)
        let report = FileScanner(home: home).scan(token: CancellationToken())
        XCTAssertTrue(report.items.isEmpty)
        XCTAssertFalse(report.warnings.isEmpty)
    }
    func testChangedFileInvalidatesSelectionWithoutWaitingForClockTick() throws {
        let url = try file("Downloads/old.pkg")
        let selected = try item(url, category: .installers)
        XCTAssertTrue(PathPolicy.revalidate(selected, home: home))
        try Data(repeating: 4, count: 8192).write(to: url)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: Double(selected.identity.modified))], ofItemAtPath: url.path)
        XCTAssertTrue(PathPolicy.isCandidate(url, category: .installers, home: home))
        XCTAssertFalse(PathPolicy.revalidate(selected, home: home))
    }
    func testParentReplacementInvalidatesSelectionEvenWithOriginalFile() throws {
        let url = try file("Downloads/old.pkg")
        let selected = try item(url, category: .installers)
        let moved = home.appendingPathComponent("PreviousDownloads")
        try FileManager.default.moveItem(at: url.deletingLastPathComponent(), to: moved)
        try FileManager.default.createDirectory(at: home.appendingPathComponent("Downloads"), withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: moved.appendingPathComponent("old.pkg"), to: url)
        XCTAssertFalse(PathPolicy.revalidate(selected, home: home))
    }
    func testCancellationAndBudgetDoNotPublishUnmeasuredCandidates() throws {
        try file("Library/Caches/example/a")
        try file("Library/Caches/example/b")
        let token = CancellationToken(); token.cancel()
        let cancelled = FileScanner(home: home).scan(token: token)
        XCTAssertFalse(cancelled.completed); XCTAssertTrue(cancelled.items.isEmpty)
        let limited = FileScanner(home: home, maxEntries: 1).scan(token: CancellationToken())
        XCTAssertFalse(limited.completed); XCTAssertTrue(limited.items.isEmpty)
    }
    func testExplorerMeasuresAndSortsWithoutFollowingLinks() throws {
        let a = try file("Documents/small", bytes: 128)
        let b = try file("Documents/folder/large", bytes: 4096)
        try FileManager.default.createSymbolicLink(at: a.deletingLastPathComponent().appendingPathComponent("link"), withDestinationURL: b)
        let report = FileScanner(home: home).inspect(home.appendingPathComponent("Documents"), token: CancellationToken())
        XCTAssertEqual(report.entries.map(\.bytes), [4096, 128])
        XCTAssertTrue(FileManager.default.fileExists(atPath: b.path))
    }
    func testHistoryRoundTripAndMalformedHistoryIsObservable() throws {
        let repository = HistoryRepository(file: fixture.appendingPathComponent("history.json"))
        XCTAssertTrue(try repository.load().isEmpty)
        let event = HistoryEvent(moved: ["file"], bytes: 1234, failed: [])
        try repository.save([event])
        XCTAssertEqual(try repository.load().first?.bytes, 1234)
        try Data("invalid".utf8).write(to: repository.file)
        XCTAssertThrowsError(try repository.load())
    }
    func testRealBridgePreviewThenFixtureTrashPreservesContents() throws {
        let url = try file("Downloads/Pawly fixture ' 貓咪.dmg")
        let selected = try item(url, category: .installers)
        let client = EngineClient(bridge: bridge, home: home)
        let trash = fixture.appendingPathComponent("test-trash")
        let preview = client.perform(selected, preview: true, testTrash: trash)
        XCTAssertTrue(preview.success, preview.detail)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let action = client.perform(selected, preview: false, testTrash: trash)
        XCTAssertTrue(action.success, action.detail)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        let restored = try FileManager.default.contentsOfDirectory(at: trash, includingPropertiesForKeys: nil)
        XCTAssertEqual(restored.count, 1)
        XCTAssertEqual(try Data(contentsOf: restored[0]), Data(repeating: 0x61, count: 2048))
        let logs = try String(contentsOf: home.appendingPathComponent("Library/Logs/mole/deletions.log"), encoding: .utf8)
        XCTAssertTrue(logs.contains("dry-run")); XCTAssertTrue(logs.contains("\tok\t"))
    }
    func testKeepListRefusesBothPreviewAndAction() throws {
        let url = try file("Downloads/Keep me.dmg")
        let selected = try item(url, category: .installers)
        try FileManager.default.createDirectory(at: home.appendingPathComponent(".config/mole"), withIntermediateDirectories: true)
        try Data((url.path + "\n").utf8).write(to: home.appendingPathComponent(".config/mole/whitelist"))
        let client = EngineClient(bridge: bridge, home: home)
        for preview in [true, false] {
            let result = client.perform(selected, preview: preview, testTrash: fixture.appendingPathComponent("test-trash"))
            XCTAssertFalse(result.success)
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        }
    }
    func testUnavailableTrashNeverFallsBackToPermanentRemoval() throws {
        let url = try file("Downloads/retain.dmg")
        let selected = try item(url, category: .installers)
        let blockedTrash = fixture.appendingPathComponent("not-a-directory")
        try Data("blocked".utf8).write(to: blockedTrash)
        let result = EngineClient(bridge: bridge, home: home).perform(selected, preview: false, testTrash: blockedTrash)
        XCTAssertFalse(result.success)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }
    func testOpenFileRefusesPreviewAndMoveWithPositiveClosedControl() throws {
        let url = try file("Downloads/open-file.dmg")
        let selected = try item(url, category: .installers)
        let client = EngineClient(bridge: bridge, home: home)
        let trash = fixture.appendingPathComponent("test-trash")
        XCTAssertTrue(client.perform(selected, preview: true, testTrash: trash).success)
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        XCTAssertFalse(client.perform(selected, preview: true, testTrash: trash).success)
        XCTAssertFalse(client.perform(selected, preview: false, testTrash: trash).success)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }
    func testFullInstallerInventoryAndRecoverableMove() throws {
        let iso = try file("Desktop/QA ' 貓.iso", bytes: 4096, ageDays: 0)
        let xip = try file("Documents/Nested/QA.xip", bytes: 2048, ageDays: 0)
        let document = try file("Documents/notes.txt")
        let client = InstallerClient(engine: bridge.deletingLastPathComponent(), home: home)
        let report = client.scan(token: CancellationToken())
        XCTAssertNil(report.error)
        XCTAssertTrue(report.files.contains { $0.url == iso })
        XCTAssertTrue(report.files.contains { $0.url == xip })
        XCTAssertFalse(report.files.contains { $0.url == document })
        let selected = try XCTUnwrap(report.files.first { $0.url == iso })
        let trash = fixture.appendingPathComponent("installer-trash")
        let preview = client.perform(selected, preview: true, token: CancellationToken(), testTrash: trash)
        XCTAssertTrue(preview.success, preview.detail)
        XCTAssertTrue(FileManager.default.fileExists(atPath: iso.path))
        let result = client.perform(selected, preview: false, token: CancellationToken(), testTrash: trash)
        XCTAssertTrue(result.success, result.detail)
        XCTAssertFalse(FileManager.default.fileExists(atPath: iso.path))
        let saved = try FileManager.default.contentsOfDirectory(at: trash, includingPropertiesForKeys: nil)
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(try Data(contentsOf: saved[0]), Data(repeating: 0x61, count: 4096))
        XCTAssertTrue(FileManager.default.fileExists(atPath: xip.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: document.path))
    }
    func testFullInstallerChangedFileAndKeepListRefuseBothModes() throws {
        let url = try file("Desktop/Keep.iso", ageDays: 0)
        let client = InstallerClient(engine: bridge.deletingLastPathComponent(), home: home)
        let report = client.scan(token: CancellationToken())
        let selected = try XCTUnwrap(report.files.first { $0.url == url })
        try FileManager.default.createDirectory(at: home.appendingPathComponent(".config/mole"), withIntermediateDirectories: true)
        try Data((url.path + "\n").utf8).write(to: home.appendingPathComponent(".config/mole/whitelist"))
        for preview in [true, false] {
            XCTAssertFalse(client.perform(selected, preview: preview, token: CancellationToken(), testTrash: fixture.appendingPathComponent("trash")).success)
        }
        try Data(repeating: 0x62, count: 8096).write(to: url)
        let changed = client.perform(selected, preview: false, token: CancellationToken(), testTrash: fixture.appendingPathComponent("trash"))
        XCTAssertFalse(changed.success)
        XCTAssertTrue(changed.detail.contains("changed"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }
}
