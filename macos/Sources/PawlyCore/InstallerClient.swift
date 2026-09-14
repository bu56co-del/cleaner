import Foundation

public struct InstallerFile: Identifiable, Sendable {
    public let url: URL
    public let source: String
    public let bytes: Int64
    public let identity: FileIdentity
    public let parent: FileIdentity
    public var id: String { url.path }
    public var name: String { url.lastPathComponent }
}

public struct InstallerInventory: Sendable {
    public var files: [InstallerFile] = []
    public var error: String?
    public var excluded = 0
    public init() {}
}

public struct InstallerClient: Sendable {
    public let engine: URL
    public let home: URL
    public init(engine: URL, home: URL = FileManager.default.homeDirectoryForCurrentUser) { self.engine = engine; self.home = home }
    public func scan(token: CancellationToken) -> InstallerInventory {
        var inventory = InstallerInventory()
        let output = CommandRunner().run(URL(fileURLWithPath: "/bin/bash"), arguments: [engine.appendingPathComponent("pawly-inventory.sh").path, "installers"],
                                         environment: CommandRunner.environment(home: home), timeout: 90, token: token)
        guard output.success else { inventory.error = output.error; return inventory }
        struct Row: Decodable { let path: String; let source: String; let bytes: Int64 }
        do {
            for row in try JSONDecoder().decode([Row].self, from: output.data) {
                let url = URL(fileURLWithPath: row.path)
                // Keep the lexical path: Foundation standardization can rewrite
                // /private/tmp to the /tmp symlink on macOS.
                guard row.path.hasPrefix("/"), row.path == url.path, PathPolicy.hasNoSymlinkComponents(url),
                      !row.path.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
                      let identity = try? FileIdentity.read(url), identity.size == row.bytes,
                      let parent = try? FileIdentity.read(url.deletingLastPathComponent()) else { inventory.excluded += 1; continue }
                inventory.files.append(InstallerFile(url: url, source: row.source, bytes: row.bytes, identity: identity, parent: parent))
            }
            inventory.files.sort { $0.bytes > $1.bytes }
        } catch { inventory.error = "Installer inventory could not be decoded: \(error.localizedDescription)" }
        return inventory
    }
    public func perform(_ file: InstallerFile, preview: Bool, token: CancellationToken, testTrash: URL? = nil) -> EngineResult {
        guard PathPolicy.hasNoSymlinkComponents(file.url),
              let current = try? FileIdentity.read(file.url), current == file.identity,
              let parent = try? FileIdentity.read(file.url.deletingLastPathComponent()), parent.device == file.parent.device, parent.inode == file.parent.inode else {
            return EngineResult(success: false, detail: "File or folder changed. Scan again.")
        }
        var environment = CommandRunner.environment(home: home)
        if let testTrash { environment["MOLE_TEST_TRASH_DIR"] = testTrash.path }
        else if !preview {
            // The bridge is non-privileged, but real Trash routing must be able
            // to use macOS's recoverable move. Test mode deliberately disables it.
            environment.removeValue(forKey: "MOLE_TEST_NO_AUTH")
        }
        let output = CommandRunner().run(URL(fileURLWithPath: "/bin/bash"),
                                         arguments: [engine.appendingPathComponent("pawly-bridge.sh").path, preview ? "preview" : "trash", "installerLibrary", file.url.path, file.identity.shellIdentity, file.parent.parentIdentity],
                                         environment: environment, timeout: 45, token: token)
        let success = output.success && String(decoding: output.data, as: UTF8.self).contains("PAWLY_OK")
        return EngineResult(success: success, detail: success ? "" : output.error.isEmpty ? "The engine did not confirm completion." : output.error)
    }
}
