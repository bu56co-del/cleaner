import SwiftUI
import PawlyCore

@MainActor @Observable
final class MoleStore {
    var apps: [InstalledApp] = [] { didSet { rebuildApps() } }
    var loadingApps = false
    var appError: String?
    var appSearch = "" { didSet { rebuildApps() } }
    var appSelection: String?
    var appSource = "all" { didSet { rebuildApps() } }
    var health: JSONValue?
    var healthError: String?
    var watching = false
    private var healthCollectors = 0
    var healthCollecting: Bool { healthCollectors > 0 }
    var healthReceivedAt: Date?
    var cpuHistory: [Double] = []
    var memoryHistory: [Double] = []
    var disk: EngineDiskReport? { didSet { rebuildDiskRows() } }
    var diskError: String?
    var loadingDisk = false
    var diskSearch = "" { didSet { rebuildDiskRows() } }
    var diskSort = "size" { didSet { rebuildDiskRows() } }
    var diskLocation: String?
    var diskBackStack: [String?] = []
    var originalHistory: JSONValue?
    var historyError: String?
    var loadingHistory = false
    var operation: OperationRequest?
    var operationFinished = false
    var operationExit: Int32?
    var operationCancelled = false
    var pendingAction: EngineAction?
    var pendingTarget: String?
    var pendingIdentity: String?
    var launchError: String?
    private(set) var nativePreviewSummary: String?
    private var nativePreviewTarget: String?
    private var nativePreviewTime: Date?
    private var historyToken: CancellationToken?
    private var appsToken: CancellationToken?
    private var healthToken: CancellationToken?
    private var diskToken: CancellationToken?
    private var appsGeneration = UUID()
    private var healthGeneration = UUID()
    private var diskGeneration = UUID()
    var engineRoot: URL { Bundle.main.resourceURL!.appendingPathComponent("engine") }
    var operationActive: Bool { operation != nil && !operationFinished }
    private(set) var visibleApps: [InstalledApp] = []
    private func rebuildApps() {
        visibleApps = apps.filter { app in
            (appSource == "all" || app.source == appSource) &&
            (appSearch.isEmpty || [app.name, app.bundleID, app.path].contains { $0.localizedCaseInsensitiveContains(appSearch) })
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    var pickedApp: InstalledApp? { apps.first { $0.id == appSelection } }
    private(set) var visibleDiskEntries: [EngineDiskReport.Entry] = []
    private func rebuildDiskRows() {
        visibleDiskEntries = (disk?.entries ?? []).filter { diskSearch.isEmpty || $0.name.localizedCaseInsensitiveContains(diskSearch) }
            .sorted { diskSort == "name" ? $0.name.localizedStandardCompare($1.name) == .orderedAscending : $0.size > $1.size }
    }
    func refreshApps() {
        guard !loadingApps, !operationActive else { return }
        let token = CancellationToken(); appsToken = token
        let generation = UUID(); appsGeneration = generation
        loadingApps = true; appError = nil
        let script = engineRoot.appendingPathComponent("bin/uninstall.sh")
        Task {
            let output = await Task.detached {
                CommandRunner().run(URL(fileURLWithPath: "/bin/bash"), arguments: [script.path, "--list"], timeout: 120, token: token)
            }.value
            guard generation == appsGeneration else { return }
            if output.success {
                do {
                    let result = try await Task.detached { try JSONDecoder().decode([InstalledApp].self, from: output.data) }.value
                    guard generation == appsGeneration else { return }
                    AppIcon.clearCache(); apps = result; appSelection = nil
                }
                catch { appError = "Application inventory format error: \(error.localizedDescription)" }
            } else { appError = output.error }
            loadingApps = false
        }
    }
    func cancelApps() { appsToken?.cancel() }
    func startHealth() {
        guard !watching else { return }
        let token = CancellationToken(); healthToken = token
        let generation = UUID(); healthGeneration = generation
        watching = true; healthCollectors += 1; healthError = nil
        let binary = engineRoot.appendingPathComponent("bin/status-go")
        Task {
            let output = await Task.detached { [self] in
                let decoder = SnapshotLines()
                return CommandRunner().run(binary, arguments: ["--watch", "--interval", "2s", "--proc-cpu-alerts=false"],
                                           timeout: 3600, token: token, collect: false) { data in
                    for value in decoder.append(data) {
                        Task { @MainActor [self] in
                            guard self.healthGeneration == generation, self.watching else { return }
                            self.health = value; self.healthReceivedAt = Date()
                            if let cpu = value["cpu"]["usage"].number { self.cpuHistory = Array((self.cpuHistory + [cpu]).suffix(45)) }
                            if let ram = value["memory"]["used_percent"].number { self.memoryHistory = Array((self.memoryHistory + [ram]).suffix(45)) }
                        }
                    }
                }
            }.value
            healthCollectors -= 1
            guard generation == healthGeneration else { return }
            watching = false
            if !output.cancelled { healthError = output.error.isEmpty ? "Live collection ended. Refresh to resume." : output.error }
        }
    }
    func stopHealth() { watching = false; healthGeneration = UUID(); healthToken?.cancel() }
    func explore(_ path: String?, remember: Bool = true) {
        if remember, disk != nil { diskBackStack.append(diskLocation) }
        diskToken?.cancel()
        let token = CancellationToken(); diskToken = token
        let generation = UUID(); diskGeneration = generation
        diskLocation = path; loadingDisk = true; diskError = nil; disk = nil; diskSearch = ""
        let binary = engineRoot.appendingPathComponent("bin/analyze-go")
        Task {
            let output = await Task.detached {
                CommandRunner().run(binary, arguments: ["--json"] + (path.map { [$0] } ?? []), timeout: 120, token: token)
            }.value
            guard generation == diskGeneration else { return }
            if output.success {
                do {
                    let result = try await Task.detached { try JSONDecoder().decode(EngineDiskReport.self, from: output.data) }.value
                    guard generation == diskGeneration else { return }
                    disk = result
                } catch {
                    guard generation == diskGeneration else { return }
                    diskError = "Disk inventory format error: \(error.localizedDescription)"
                }
            } else { diskError = output.error }
            loadingDisk = false
        }
    }
    func goBack() {
        guard !diskBackStack.isEmpty else { return }
        let path = diskBackStack.removeLast()
        explore(path, remember: false)
    }
    func chooseDiskFolder() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.begin { response in if response == .OK, let url = panel.url { self.explore(url.path) } }
    }
    func cancelDisk() { diskToken?.cancel() }
    func refreshHistory() {
        guard !loadingHistory else { return }
        loadingHistory = true; historyError = nil
        let token = CancellationToken(); historyToken = token
        let script = engineRoot.appendingPathComponent("bin/history.sh")
        Task {
            let output = await Task.detached {
                CommandRunner().run(URL(fileURLWithPath: "/bin/bash"), arguments: [script.path, "--json", "--limit", "100"], timeout: 20, token: token)
            }.value
            loadingHistory = false
            if output.success {
                do { originalHistory = try JSONDecoder().decode(JSONValue.self, from: output.data) }
                catch { historyError = error.localizedDescription }
            } else { historyError = output.error }
        }
    }
    func cancelAllWork() {
        appsToken?.cancel(); diskToken?.cancel(); historyToken?.cancel(); stopHealth()
    }
    func prepare(_ action: EngineAction, target: String? = nil) {
        guard !operationActive else { return }
        // Reopening a workflow starts a fresh review; a previous successful
        // preview never authorizes a new selection or replacement app.
        operation = nil; operationFinished = false; operationExit = nil; operationCancelled = false
        nativePreviewSummary = nil; nativePreviewTarget = nil; nativePreviewTime = nil
        pendingAction = action; pendingTarget = target; pendingIdentity = nil; launchError = nil
        if [.uninstall, .cliUpdate, .cliRemove].contains(action), let target {
            guard let identity = try? FileIdentity.read(URL(fileURLWithPath: target)) else {
                launchError = "App changed or is unavailable. Refresh the list."; pendingAction = nil; return
            }
            pendingIdentity = identity.shellIdentity
        }
    }
    func acceptMaintenancePreview(_ summary: String) {
        guard pendingAction == .optimize, let target = pendingTarget, !target.isEmpty, !operationActive else { return }
        nativePreviewSummary = summary; nativePreviewTarget = target; nativePreviewTime = Date()
    }
    func acceptDeepCleanPreview(_ summary: String) {
        guard pendingAction == .deepClean, pendingTarget == nil, !operationActive else { return }
        nativePreviewSummary = summary; nativePreviewTarget = nil; nativePreviewTime = Date()
    }
    func acceptUninstallPreview(_ summary: String) {
        guard pendingAction == .uninstall, pendingTarget != nil, pendingIdentity != nil, !operationActive else { return }
        nativePreviewSummary = summary; nativePreviewTarget = pendingTarget; nativePreviewTime = Date()
    }
    func launch(preview: Bool) {
        guard !operationActive, let action = pendingAction else { return }
        if !preview && (action.supportsPreview || action == .touchID) {
            let nativeReviewed = [.optimize, .deepClean, .uninstall].contains(action) && pendingTarget == nativePreviewTarget && nativePreviewSummary != nil &&
                nativePreviewTime.map { Date().timeIntervalSince($0) < 600 } == true
            let terminalReviewed = operation.map { $0.preview && operationFinished && operationExit == 0 && !operationCancelled &&
                $0.action == action && $0.target == pendingTarget && $0.identity == pendingIdentity } ?? false
            guard nativeReviewed || terminalReviewed else { launchError = "Preview expired. Preview your selection again."; return }
        }
        nativePreviewTime = nil
        operation = OperationRequest(action: action, preview: preview, target: pendingTarget, identity: pendingIdentity)
        operationFinished = false; operationExit = nil; operationCancelled = false
    }
    func endOperation(_ id: UUID, exitCode: Int32?) {
        guard operation?.id == id else { return }
        operationFinished = true; operationExit = exitCode
    }
}

private final class SnapshotLines: @unchecked Sendable {
    private var pending = Data()
    func append(_ data: Data) -> [JSONValue] {
        pending.append(data)
        var snapshots: [JSONValue] = []
        while let newline = pending.firstIndex(of: 10) {
            let line = pending[..<newline]
            pending.removeSubrange(...newline)
            if let value = try? JSONDecoder().decode(JSONValue.self, from: line), value["cpu"]["usage"].number != nil { snapshots.append(value) }
        }
        if pending.count > 4 * 1024 * 1024 { pending.removeAll() }
        return snapshots
    }
}
