import Foundation

public struct HistoryEvent: Identifiable, Codable, Sendable {
    public let id: UUID
    public let date: Date
    public let moved: [String]
    public let bytes: Int64
    public let failed: [String]
    public init(moved: [String], bytes: Int64, failed: [String]) {
        self.id = UUID(); self.date = Date(); self.moved = moved; self.bytes = bytes; self.failed = failed
    }
}

public struct HistoryRepository: Sendable {
    public let file: URL
    public init(file: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Pawly/history.json")) {
        self.file = file
    }
    public func load() throws -> [HistoryEvent] {
        guard FileManager.default.fileExists(atPath: file.path) else { return [] }
        return try JSONDecoder().decode([HistoryEvent].self, from: Data(contentsOf: file))
    }
    public func save(_ events: [HistoryEvent]) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        let data = try JSONEncoder().encode(Array(events.prefix(100)))
        try data.write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }
}
