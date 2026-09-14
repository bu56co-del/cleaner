import Foundation

public enum PathPolicy {
    public static func hasNoSymlinkComponents(_ url: URL) -> Bool {
        // Foundation may rewrite /private/var to the /var symlink when standardizing.
        // Validate lexical components and lstat each original component instead.
        guard !url.pathComponents.contains(".."), !url.pathComponents.contains("."),
              !url.path.contains("\n"), !url.path.contains("\t"), !url.path.contains("//") else { return false }
        var current = url
        while current.path != "/" {
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: current.path),
                  attrs[.type] as? FileAttributeType != .typeSymbolicLink else { return false }
            current.deleteLastPathComponent()
        }
        return true
    }

    public static func isCandidate(_ url: URL, category: CleanupCategory, home: URL, now: Date = Date()) -> Bool {
        guard hasNoSymlinkComponents(url), url.path.hasPrefix(home.path + "/"),
              let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .contentModificationDateKey, .isUbiquitousItemKey]),
              values.isUbiquitousItem != true else { return false }
        let relative = String(url.path.dropFirst(home.path.count + 1))
        let name = url.lastPathComponent.lowercased()
        switch category {
        case .caches:
            guard url.deletingLastPathComponent().path == home.appendingPathComponent("Library/Caches").path else { return false }
            let excluded = ["com.apple.", "codex", "claude", "com.anthropic", "opencode", "huggingface", "torch", "orbstack", "cloudkit"]
            return !excluded.contains(where: { name.contains($0) }) && !name.hasPrefix(".")
        case .logs:
            return relative.hasPrefix("Library/Logs/") && values.isRegularFile == true && url.pathExtension.lowercased() == "log"
                && (values.contentModificationDate.map { now.timeIntervalSince($0) >= 14 * 86400 } ?? false)
        case .installers:
            return url.deletingLastPathComponent().path == home.appendingPathComponent("Downloads").path
                && values.isRegularFile == true && ["dmg", "pkg"].contains(url.pathExtension.lowercased())
                && (values.contentModificationDate.map { now.timeIntervalSince($0) >= 7 * 86400 } ?? false)
        }
    }

    public static func revalidate(_ item: CleanupItem, home: URL) -> Bool {
        guard isCandidate(item.url, category: item.category, home: home),
              let current = try? FileIdentity.read(item.url), current == item.identity,
              let parent = try? FileIdentity.read(item.url.deletingLastPathComponent()),
              parent.parentIdentity == item.parentIdentity.parentIdentity else { return false }
        return true
    }
}
