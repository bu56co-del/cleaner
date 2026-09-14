import Foundation
import Darwin

public enum CleanupCategory: String, CaseIterable, Codable, Sendable, Identifiable {
    case caches, logs, installers
    public var id: String { rawValue }
}

public struct FileIdentity: Codable, Hashable, Sendable {
    public let device: Int32
    public let inode: UInt64
    public let modified: Int64
    public let nanos: Int64
    public let size: Int64

    public static func read(_ url: URL) throws -> FileIdentity {
        var info = stat()
        guard lstat(url.path, &info) == 0 else { throw CocoaError(.fileReadNoSuchFile) }
        guard (info.st_mode & S_IFMT) != S_IFLNK else { throw CocoaError(.fileReadInvalidFileName) }
        return FileIdentity(device: info.st_dev, inode: info.st_ino,
                            modified: Int64(info.st_mtimespec.tv_sec), nanos: Int64(info.st_mtimespec.tv_nsec),
                            size: info.st_size)
    }
    public var shellIdentity: String { "\(device):\(inode):\(modified)" }
    public var parentIdentity: String { "\(device):\(inode)" }
}

public struct CleanupItem: Identifiable, Codable, Hashable, Sendable {
    public var id: String { url.path }
    public let url: URL
    public let category: CleanupCategory
    public let bytes: Int64
    public let fileCount: Int
    public let identity: FileIdentity
    public let parentIdentity: FileIdentity
    public var name: String { url.lastPathComponent }

    public init(url: URL, category: CleanupCategory, bytes: Int64, fileCount: Int,
                identity: FileIdentity, parentIdentity: FileIdentity) {
        self.url = url; self.category = category; self.bytes = bytes; self.fileCount = fileCount
        self.identity = identity; self.parentIdentity = parentIdentity
    }
}

public struct ScanReport: Sendable {
    public var items: [CleanupItem] = []
    public var scannedCategories: Set<CleanupCategory> = []
    public var warnings: [String] = []
    public var visited = 0
    public var completed = true
    public var date = Date()
    public init() {}
    public var bytes: Int64 { items.reduce(0) { $0 + $1.bytes } }
}

public struct DiskEntry: Identifiable, Sendable {
    public var id: String { url.path }
    public let url: URL
    public let bytes: Int64
    public let isDirectory: Bool
}

public struct DiskReport: Sendable {
    public var entries: [DiskEntry] = []
    public var warnings: [String] = []
    public var completed = true
    public init() {}
}

public final class CancellationToken: @unchecked Sendable {
    private let lock = NSLock()
    private var flag = false
    public init() {}
    public func cancel() { lock.withLock { flag = true } }
    public var isCancelled: Bool { lock.withLock { flag } }
}

public enum FileSize {
    public static func string(_ bytes: Int64) -> String {
        if bytes <= 0 { return "0 KB" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.includesActualByteCount = false
        return formatter.string(fromByteCount: max(0, bytes))
    }
}
