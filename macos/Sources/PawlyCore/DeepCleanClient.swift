import Foundation

public struct DeepCleanReport: Decodable, Sendable {
    public let complete: Bool
    public let systemIncluded: Bool
    public let items: [Item]
    public struct Item: Decodable, Sendable, Identifiable {
        public let id: String
        public let path: String
        public let section: String
        public let bytes: Int64
        public let count: Int
        public let known: Bool
    }
}
public struct DeepCleanClient: Sendable {
    public let engine: URL
    public init(engine: URL) { self.engine = engine }
    public func preview(token: CancellationToken, receive: @escaping @Sendable (DeepCleanReport) -> Void = { _ in }) throws -> DeepCleanReport {
        let snapshots = DeepCleanSnapshots()
        let output = CommandRunner().run(URL(fileURLWithPath: "/bin/bash"), arguments: [engine.appendingPathComponent("pawly-clean-preview.sh").path], timeout: 600, token: token, collect: false) { data in
            for report in snapshots.append(data) { receive(report) }
        }
        guard output.success else { throw Failure(message: output.error) }
        guard let report = snapshots.latest else { throw Failure(message: "No complete preview data was returned.") }; return report
    }
    private struct Failure: LocalizedError { let message: String; var errorDescription: String? { message } }
}

private final class DeepCleanSnapshots: @unchecked Sendable {
    // CommandRunner calls append sequentially on its one worker thread.
    private var pending = Data()
    private(set) var latest: DeepCleanReport?
    func append(_ data: Data) -> [DeepCleanReport] {
        pending.append(data)
        var reports: [DeepCleanReport] = []
        while let end = pending.firstIndex(of: 10) {
            let line = pending[..<end]; pending.removeSubrange(...end)
            if let report = try? JSONDecoder().decode(DeepCleanReport.self, from: line) { latest = report; reports.append(report) }
        }
        if pending.count > 16 * 1024 * 1024 { pending.removeAll() }
        return reports
    }
}
