import SwiftUI
import PawlyCore

@MainActor @Observable
final class InstallerStore {
    var inventory: InstallerInventory?
    var selected: Set<String> = []
    var search = ""
    var source = "all"
    var scanning = false
    var reviewing = false
    var cleaning = false
    var reviewVisible = false
    var plan: [InstallerFile] = []
    var results: [String: EngineResult] = [:]
    var current = ""
    var outcome: String?
    var hasFailures = false
    private var token: CancellationToken?
    var busy: Bool { scanning || reviewing || cleaning }
    var client: InstallerClient { InstallerClient(engine: Bundle.main.resourceURL!.appendingPathComponent("engine")) }
    var sources: [String] { Array(Set((inventory?.files ?? []).map(\.source))).sorted() }
    var visible: [InstallerFile] {
        (inventory?.files ?? []).filter { (source == "all" || $0.source == source) && (search.isEmpty || $0.url.path.localizedCaseInsensitiveContains(search)) }
    }
    var picked: [InstallerFile] { (inventory?.files ?? []).filter { selected.contains($0.id) } }
    var pickedBytes: Int64 { picked.reduce(0) { $0 + $1.bytes } }
    var ready: [InstallerFile] { plan.filter { results[$0.id]?.success == true } }
    func scan() {
        guard !busy else { return }
        let client = client; let token = CancellationToken(); self.token = token
        scanning = true; selected.removeAll(); outcome = nil
        Task {
            inventory = await Task.detached { client.scan(token: token) }.value
            scanning = false
        }
    }
    func cancel() { token?.cancel() }
    func review() {
        guard !busy, !picked.isEmpty else { return }
        plan = picked; results = [:]; reviewing = true; reviewVisible = true
        let client = client; let token = CancellationToken(); self.token = token
        let files = plan
        Task {
            let deadline = Date().addingTimeInterval(180)
            for file in files {
                guard !token.isCancelled, Date() < deadline else { break }
                current = file.name
                results[file.id] = await Task.detached { client.perform(file, preview: true, token: token) }.value
            }
            current = ""; reviewing = false
        }
    }
    func moveConfirmed(record: @escaping ([String], Int64, [String]) -> Void) {
        guard !busy, !ready.isEmpty else { return }
        let client = client; let files = ready; let token = CancellationToken(); self.token = token
        cleaning = true
        Task {
            var moved: [String] = []; var bytes: Int64 = 0; var failures: [String] = []
            let deadline = Date().addingTimeInterval(180)
            for file in files {
                guard !token.isCancelled, Date() < deadline else { failures.append("Remaining items were not processed."); break }
                current = file.name
                let result = await Task.detached { client.perform(file, preview: false, token: token) }.value
                if result.success {
                    moved.append(file.id); bytes += file.bytes
                    inventory?.files.removeAll { $0.id == file.id }; selected.remove(file.id)
                } else { failures.append(file.name + ": " + result.detail); break }
            }
            record(moved, bytes, failures)
            hasFailures = !failures.isEmpty
            outcome = "\(moved.count) 個安裝檔已移到垃圾桶 / \(moved.count) installers moved to Trash. " + failures.joined(separator: "\n")
            current = ""; cleaning = false; reviewVisible = false
        }
    }
}
