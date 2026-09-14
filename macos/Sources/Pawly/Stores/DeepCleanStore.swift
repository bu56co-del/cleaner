import SwiftUI
import PawlyCore

@MainActor @Observable
final class DeepCleanStore {
    var report: DeepCleanReport? { didSet { rebuildRows() } }
    var scanning = false
    var error: String?
    var search = "" { didSet { rebuildRows() } }
    var scannedAt: Date?
    private var token: CancellationToken?
    struct Group: Identifiable {
        let id: String
        let items: [DeepCleanReport.Item]
    }
    private(set) var groups: [Group] = []
    private(set) var measuredBytes: Int64 = 0
    private func rebuildRows() {
        let items = report?.items ?? []
        measuredBytes = items.reduce(0) { $0 + $1.bytes }
        let visible = items.filter { search.isEmpty || $0.path.localizedCaseInsensitiveContains(search) || $0.section.localizedCaseInsensitiveContains(search) }
        groups = Dictionary(grouping: visible, by: \.section)
            .map { Group(id: $0.key, items: $0.value) }.sorted { $0.id < $1.id }
    }
    var canProceed: Bool { report?.complete == true && scannedAt.map { Date().timeIntervalSince($0) < 600 } == true && !scanning }
    func scan() {
        guard !scanning else { return }
        let client = DeepCleanClient(engine: Bundle.main.resourceURL!.appendingPathComponent("engine"))
        let token = CancellationToken(); self.token = token
        scanning = true; report = nil; error = nil; scannedAt = nil
        Task {
            do {
                report = try await Task.detached {
                    try client.preview(token: token) { snapshot in
                        Task { @MainActor in if self.scanning && self.token === token && !token.isCancelled { self.report = snapshot } }
                    }
                }.value
                scannedAt = Date()
            }
            catch { self.error = error.localizedDescription }
            scanning = false
        }
    }
    func cancel() { token?.cancel() }
}
