import Foundation

public struct EngineResult: Sendable {
    public let success: Bool
    public let detail: String
}

public struct EngineClient: Sendable {
    public let bridge: URL
    public let home: URL
    public init(bridge: URL, home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.bridge = bridge; self.home = home
    }

    public func perform(_ item: CleanupItem, preview: Bool, testTrash: URL? = nil, token: CancellationToken = CancellationToken()) -> EngineResult {
        guard PathPolicy.revalidate(item, home: home) else {
            return EngineResult(success: false, detail: "File or folder changed. Scan again.")
        }
        guard FileManager.default.fileExists(atPath: bridge.path) else {
            return EngineResult(success: false, detail: "Cleaning engine is missing. Rebuild Pawly.")
        }
        var environment = CommandRunner.environment(home: home)
        environment["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin"
        if let testTrash { environment["MOLE_TEST_TRASH_DIR"] = testTrash.path }
        else if !preview { environment.removeValue(forKey: "MOLE_TEST_NO_AUTH") }
        let output = CommandRunner().run(URL(fileURLWithPath: "/bin/bash"),
            arguments: [bridge.path, preview ? "preview" : "trash", item.category.rawValue,
                        item.url.path, item.identity.shellIdentity, item.parentIdentity.parentIdentity],
            environment: environment, timeout: 50, token: token)
        let ok = output.success && String(decoding: output.data, as: UTF8.self).contains("PAWLY_OK")
        return EngineResult(success: ok, detail: ok ? "" : output.error.isEmpty ? "The engine did not confirm completion. Scan again." : output.error)
    }
}
