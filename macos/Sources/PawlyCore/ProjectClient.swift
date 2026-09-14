import Foundation

public struct ProjectArtifact: Decodable, Sendable, Identifiable {
    public let path: String
    public let project: String
    public let artifact: String
    public let bytes: Int64
    public let unknownSize: Bool
    public let activity: String
    public let age: String
    public let cloud: Bool
    public let targetIdentity: String
    public let parentIdentity: String
    public let scanRoot: String
    public let rootBindings: [String]
    public var id: String { path }
    /// Upstream grouping may name a monorepo above the scanned folder. Never
    /// use that presentation label to broaden the next cleanup's scan scope.
    public func reviewRoot(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> String {
        let label = project.hasPrefix("[cloud] ") ? String(project.dropFirst(8)) : project
        let candidate = label.hasPrefix("~/") ? home.path + label.dropFirst() : label
        guard candidate.hasPrefix("/"), !candidate.split(separator: "/").contains(where: { $0 == "." || $0 == ".." }),
              candidate == scanRoot || candidate.hasPrefix(scanRoot.hasSuffix("/") ? scanRoot : scanRoot + "/") else { return scanRoot }
        return candidate
    }
}
public struct ProjectInventory: Decodable, Sendable {
    public let outcome: String
    public let items: [ProjectArtifact]
    public var complete: Bool { ["completed", "no_candidates"].contains(outcome) }
}
public struct ProjectClient: Sendable {
    public let engine: URL
    public let home: URL
    public init(engine: URL, home: URL = FileManager.default.homeDirectoryForCurrentUser) { self.engine = engine; self.home = home }
    public func scan(location: String?, token: CancellationToken) throws -> ProjectInventory {
        let output = CommandRunner().run(URL(fileURLWithPath: "/bin/bash"),
            arguments: [engine.appendingPathComponent("pawly-projects.sh").path, "inventory"] + (location.map { [$0] } ?? []),
            environment: CommandRunner.environment(home: home), timeout: 150, token: token)
        guard output.success else { throw Failure(message: output.error) }
        return try JSONDecoder().decode(ProjectInventory.self, from: output.data)
    }
    public func perform(_ selection: [ProjectArtifact], preview: Bool, token: CancellationToken) throws -> ProjectOutcome {
        guard !selection.isEmpty, selection.count <= 100, Set(selection.map(\.id)).count == selection.count else { throw Failure(message: "Select 1–100 distinct artifacts.") }
        let tuples = selection.flatMap { [$0.path, $0.targetIdentity, $0.parentIdentity, $0.activity, String($0.cloud), String($0.bytes), String($0.unknownSize)] + $0.rootBindings }
        guard selection.allSatisfy({ $0.rootBindings.count == 6 && $0.rootBindings.first == $0.scanRoot }),
              tuples.allSatisfy({ !$0.isEmpty && !$0.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) }),
              tuples.reduce(0, { $0 + $1.utf8.count + 1 }) < 120_000 else { throw Failure(message: "This selection cannot be represented safely. Choose fewer artifacts and scan again.") }
        let output = CommandRunner().run(URL(fileURLWithPath: "/bin/bash"),
            arguments: [engine.appendingPathComponent("pawly-projects.sh").path, preview ? "preview-selection" : "purge-selection", String(selection.count)] + tuples,
            environment: CommandRunner.environment(home: home), timeout: 180, token: token)
        guard output.success else { throw Failure(message: output.error) }
        return try JSONDecoder().decode(ProjectOutcome.self, from: output.data)
    }
    private struct Failure: LocalizedError { let message: String; var errorDescription: String? { message } }
}
public struct ProjectOutcome: Decodable, Sendable {
    public let outcome: String
    public let processed: Int
    public func completed(_ count: Int) -> Bool { outcome == "completed" && processed == count }
}
