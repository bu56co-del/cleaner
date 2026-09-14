import Foundation

public struct UninstallReview: Decodable, Sendable {
    public let path: String
    public let identity: String
    public let sensitive: Bool
    public let needsAdmin: Bool
    public let shared: Bool
    public let files: [File]
    public struct File: Decodable, Sendable { public let path: String; public let kind: String }
    public static func load(app: InstalledApp, engine: URL, token: CancellationToken) throws -> Self {
        let identity = try FileIdentity.read(URL(fileURLWithPath: app.path))
        let result = CommandRunner().run(URL(fileURLWithPath: "/bin/bash"), arguments: [engine.appendingPathComponent("pawly-console.sh").path, "uninstallReview", "preview", app.path, identity.shellIdentity], timeout: 150, token: token)
        guard result.success else { throw Failure(message: result.error) }
        let review = try JSONDecoder().decode(Self.self, from: result.data)
        guard review.path == app.path, review.identity == identity.shellIdentity else { throw Failure(message: "App changed. Scan again.") }
        return review
    }
    private struct Failure: LocalizedError { let message: String; var errorDescription: String? { message } }
}
