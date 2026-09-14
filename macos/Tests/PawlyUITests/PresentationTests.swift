import XCTest
import AppKit
import SwiftTerm
import PawlyCore
@testable import Pawly

final class PresentationTests: XCTestCase {
    @MainActor func testTerminalTakesFocusAfterAttachmentAndButtonUse() async {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 700, height: 400), styleMask: [.titled], backing: .buffered, defer: false)
        // The original plain TerminalView leaves the window as first responder.
        let original = TerminalView(frame: window.contentView!.bounds)
        window.contentView = original
        XCTAssertFalse(window.firstResponder === original)

        let terminal = PawlyTerminalView(frame: original.frame)
        window.contentView = terminal
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertTrue(window.firstResponder === terminal)
        let button = NSButton(title: "Control", target: nil, action: nil)
        terminal.addSubview(button)
        window.makeFirstResponder(button)
        terminal.focusKeyboard()
        XCTAssertTrue(window.firstResponder === terminal)
    }

    @MainActor func testProgressAndSearchReplacePresentationWithoutAuthorizingPartialScan() throws {
        let store = DeepCleanStore()
        func report(_ items: String) throws -> DeepCleanReport {
            try JSONDecoder().decode(DeepCleanReport.self, from: Data("{\"complete\":false,\"systemIncluded\":false,\"items\":[\(items)]}".utf8))
        }
        let one = #"{"id":"1","path":"/fixture/one","section":"User","bytes":40,"count":1,"known":true}"#
        let two = #"{"id":"2","path":"/fixture/two","section":"Browser","bytes":60,"count":1,"known":true}"#
        store.report = try report(one)
        store.search = "browser"
        XCTAssertTrue(store.groups.isEmpty)
        store.report = try report(one + "," + two)
        XCTAssertEqual(store.groups.map(\.id), ["Browser"])
        XCTAssertEqual(store.measuredBytes, 100)
        XCTAssertFalse(store.canProceed)
        store.search = ""
        XCTAssertEqual(store.groups.flatMap(\.items).count, 2)
        store.report = nil
        XCTAssertTrue(store.groups.isEmpty)
        XCTAssertEqual(store.measuredBytes, 0)
    }

    @MainActor func testDiskFilteringAndSortFollowNewReport() throws {
        let store = MoleStore()
        let data = Data(#"{"path":"/fixture","overview":false,"total_size":30,"entries":[{"name":"Alpha","path":"/fixture/a","size":10,"is_dir":true},{"name":"Beta","path":"/fixture/b","size":20,"is_dir":false}]}"#.utf8)
        store.disk = try JSONDecoder().decode(EngineDiskReport.self, from: data)
        XCTAssertEqual(store.visibleDiskEntries.map(\.name), ["Beta", "Alpha"])
        store.diskSort = "name"
        XCTAssertEqual(store.visibleDiskEntries.map(\.name), ["Alpha", "Beta"])
        store.diskSearch = "beta"
        XCTAssertEqual(store.visibleDiskEntries.map(\.name), ["Beta"])
        store.disk = nil
        XCTAssertTrue(store.visibleDiskEntries.isEmpty)
    }
}
