import Foundation

/// Read-only discovery. A candidate is a review suggestion, never deletion authority.
public struct FileScanner: Sendable {
    public let home: URL
    public let budget: TimeInterval
    public let maxEntries: Int
    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser,
                budget: TimeInterval = 40, maxEntries: Int = 180_000) {
        self.home = home; self.budget = budget; self.maxEntries = maxEntries
    }

    public func scan(token: CancellationToken, progress: @Sendable (String) -> Void = { _ in }) -> ScanReport {
        let walker = Walker(token: token, budget: budget, maxEntries: maxEntries)
        var report = ScanReport()
        // Cheap file-only scopes finish before potentially large cache trees use the budget.
        let roots: [(CleanupCategory, String)] = [(.installers, "Downloads"), (.logs, "Library/Logs"), (.caches, "Library/Caches")]
        for (category, relative) in roots {
            guard walker.canContinue else { report.completed = false; break }
            let root = home.appendingPathComponent(relative)
            progress(relative)
            guard PathPolicy.hasNoSymlinkComponents(root) else {
                report.warnings.append(relative + ": folder unavailable or symbolic link; not scanned")
                continue
            }
            guard let children = try? walker.children(root) else {
                report.warnings.append(relative + ": access unavailable"); continue
            }
            for child in children {
                guard walker.canContinue else { report.completed = false; break }
                guard !child.lastPathComponent.hasPrefix("."),
                      let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
                      values.isSymbolicLink != true else { continue }
                if category == .logs, values.isDirectory == true {
                    if ["mole", "Pawly"].contains(child.lastPathComponent) { continue }
                    do {
                        for file in try walker.children(child) {
                            if let item = candidate(file, category: category, walker: walker) { report.items.append(item) }
                        }
                    } catch { report.warnings.append(child.lastPathComponent + ": access unavailable") }
                } else if let item = candidate(child, category: category, walker: walker) {
                    report.items.append(item)
                }
            }
            if walker.canContinue { report.scannedCategories.insert(category) }
        }
        report.items.sort { $0.bytes > $1.bytes }
        report.visited = walker.visited
        report.warnings += walker.warnings
        report.completed = report.completed && walker.canContinue
        if !report.completed { report.warnings.append(token.isCancelled ? "Scan cancelled" : "Scan limit reached; unmeasured items excluded") }
        return report
    }

    private func candidate(_ url: URL, category: CleanupCategory, walker: Walker) -> CleanupItem? {
        guard PathPolicy.isCandidate(url, category: category, home: home),
              let before = try? FileIdentity.read(url),
              let parent = try? FileIdentity.read(url.deletingLastPathComponent()),
              let measurement = walker.measure(url), measurement.bytes > 0,
              let after = try? FileIdentity.read(url), before == after else { return nil }
        return CleanupItem(url: url, category: category, bytes: measurement.bytes,
                           fileCount: measurement.files, identity: after, parentIdentity: parent)
    }

    public func inspect(_ root: URL, token: CancellationToken) -> DiskReport {
        let walker = Walker(token: token, budget: budget, maxEntries: maxEntries)
        var report = DiskReport()
        guard PathPolicy.hasNoSymlinkComponents(root), let children = try? walker.children(root) else {
            report.warnings = ["Folder unavailable or symbolic link"]; report.completed = false; return report
        }
        for child in children {
            guard walker.canContinue else { report.completed = false; break }
            guard let values = try? child.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey]),
                  values.isSymbolicLink != true, let size = walker.measure(child) else { continue }
            report.entries.append(DiskEntry(url: child, bytes: size.bytes, isDirectory: values.isDirectory == true))
        }
        report.entries.sort { $0.bytes > $1.bytes }
        report.warnings += walker.warnings
        report.completed = report.completed && walker.canContinue
        return report
    }
}

private final class Walker {
    let token: CancellationToken
    let deadline: TimeInterval
    let maxEntries: Int
    var visited = 0
    var warnings: [String] = []
    let fm = FileManager.default
    let keys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .isUbiquitousItemKey]
    init(token: CancellationToken, budget: TimeInterval, maxEntries: Int) {
        self.token = token; self.deadline = ProcessInfo.processInfo.systemUptime + budget; self.maxEntries = maxEntries
    }
    var canContinue: Bool { !token.isCancelled && ProcessInfo.processInfo.systemUptime < deadline && visited < maxEntries }
    func children(_ root: URL) throws -> [URL] {
        try fm.contentsOfDirectory(at: root, includingPropertiesForKeys: Array(keys), options: [])
    }
    func measure(_ root: URL) -> (bytes: Int64, files: Int)? {
        guard canContinue, let rootValues = try? root.resourceValues(forKeys: keys), rootValues.isSymbolicLink != true else { return nil }
        if rootValues.isRegularFile == true { visited += 1; return (Int64(rootValues.fileSize ?? 0), 1) }
        guard rootValues.isDirectory == true else { return nil }
        var complete = true
        guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: Array(keys), options: [], errorHandler: { _, _ in
            complete = false; return false
        }) else { return nil }
        var bytes: Int64 = 0
        var files = 0
        for case let child as URL in enumerator {
            guard canContinue else { return nil }
            visited += 1
            guard let values = try? child.resourceValues(forKeys: keys) else { complete = false; continue }
            if values.isSymbolicLink == true || values.isUbiquitousItem == true { enumerator.skipDescendants(); complete = false; continue }
            if values.isRegularFile == true { bytes += Int64(values.fileSize ?? 0); files += 1 }
        }
        if !complete { warnings.append(root.lastPathComponent + ": incomplete measurement; excluded"); return nil }
        return (bytes, files)
    }
}
