import SwiftUI
import PawlyCore

@MainActor @Observable
final class ProjectStore {
    var inventory: ProjectInventory? { didSet { rebuildGroups() } }
    var location: String?
    var scanning = false
    var reviewing = false
    var cleaning = false
    var reviewVisible = false
    var selected: Set<String> = []
    var plan: [ProjectArtifact] = []
    var reviewPassed = false
    var outcome: String?
    var busy: Bool { scanning || reviewing || cleaning }
    var picked: [ProjectArtifact] { (inventory?.items ?? []).filter { selected.contains($0.id) } }
    var error: String?
    var search = "" { didSet { rebuildGroups() } }
    private var token: CancellationToken?
    private var reviewedAt: Date?
    private var client: ProjectClient { ProjectClient(engine: Bundle.main.resourceURL!.appendingPathComponent("engine")) }
    private(set) var visible: [ProjectArtifact] = []
    struct Group: Identifiable {
        let id: String
        let reviewRoot: String
        let items: [ProjectArtifact]
        let bytes: Int64
    }
    private(set) var groups: [Group] = []
    private func rebuildGroups() {
        visible = (inventory?.items ?? []).filter { search.isEmpty || $0.path.localizedCaseInsensitiveContains(search) }
        groups = Dictionary(grouping: visible, by: { $0.reviewRoot() }).map { Group(id: $0.key, reviewRoot: $0.key, items: $0.value, bytes: $0.value.reduce(0) { $0 + $1.bytes }) }
            .sorted { $0.bytes == $1.bytes ? $0.id < $1.id : $0.bytes > $1.bytes }
    }
    func scan(_ path: String? = nil) {
        guard !busy else { return }
        let client = client
        let token = CancellationToken(); self.token = token
        location = path; scanning = true; error = nil; inventory = nil; selected = []; outcome = nil; reviewPassed = false
        Task {
            do { inventory = try await Task.detached { try client.scan(location: path, token: token) }.value }
            catch { self.error = error.localizedDescription }
            scanning = false
        }
    }
    func review() {
        guard !busy, inventory?.complete == true, !picked.isEmpty else { return }
        plan = picked; reviewPassed = false; reviewing = true; reviewVisible = true; error = nil
        let files = plan; let client = client; let token = CancellationToken(); self.token = token
        Task {
            do {
                let result = try await Task.detached { try client.perform(files, preview: true, token: token) }.value
                reviewPassed = result.completed(files.count)
                if !reviewPassed { error = "檢查未完整完成，請重新掃描。 / Review incomplete; scan again." }
                reviewedAt = Date()
            } catch { self.error = error.localizedDescription }
            reviewing = false
        }
    }
    func purgeConfirmed() {
        guard !busy, reviewPassed, let reviewedAt, Date().timeIntervalSince(reviewedAt) < 600 else {
            reviewPassed = false; error = "檢查已過期，請重新掃描。 / Review expired; scan again."; return
        }
        let files = plan; let client = client; let token = CancellationToken(); self.token = token
        cleaning = true; error = nil; reviewPassed = false
        Task {
            do {
                let result = try await Task.detached { try client.perform(files, preview: false, token: token) }.value
                outcome = "已處理 \(result.processed) / \(files.count) 個產物 · \(result.outcome) / \(result.processed) of \(files.count) artifacts processed."
                if !result.completed(files.count) { error = "部分項目未完成，請重新掃描檢查。 / Some items were not completed; scan again." }
            } catch { self.error = error.localizedDescription }
            cleaning = false; reviewVisible = false; inventory = nil; selected = []
        }
    }
    func cancel() { token?.cancel() }
    func choose() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = false
        panel.begin { response in if response == .OK, let url = panel.url { self.scan(url.path) } }
    }
}
