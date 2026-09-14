import Foundation

public struct MaintenanceTask: Decodable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let detail: String
    public let excluded: Bool
}

public struct MaintenancePreview: Decodable, Sendable {
    public let id: String
    public let outcome: String
    public let detail: String
    public var allowsExecution: Bool { ["applied", "unchanged", "skipped", "unavailable", "attention"].contains(outcome) }
}

public struct MaintenanceClient: Sendable {
    public let engine: URL
    public let home: URL
    public init(engine: URL, home: URL = FileManager.default.homeDirectoryForCurrentUser) { self.engine = engine; self.home = home }
    public func catalog(token: CancellationToken) throws -> [MaintenanceTask] {
        try call(["catalog"], token: token, timeout: 15)
    }
    public func preview(_ action: String, token: CancellationToken) throws -> MaintenancePreview {
        let result: MaintenancePreview = try call(["preview", action], token: token, timeout: 60)
        guard result.id == action else { throw Failure(message: "Maintenance preview did not match the selected task.") }
        return result
    }
    private func call<T: Decodable>(_ arguments: [String], token: CancellationToken, timeout: TimeInterval) throws -> T {
        let output = CommandRunner().run(URL(fileURLWithPath: "/bin/bash"), arguments: [engine.appendingPathComponent("pawly-maintenance.sh").path] + arguments,
                                         environment: CommandRunner.environment(home: home), timeout: timeout, token: token)
        guard output.success else { throw Failure(message: output.error) }
        return try JSONDecoder().decode(T.self, from: output.data)
    }
    private struct Failure: LocalizedError { let message: String; var errorDescription: String? { message } }
}
