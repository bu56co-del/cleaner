import SwiftUI
import PawlyCore

enum Page: String, CaseIterable, Identifiable {
    case home, cleanup, deepClean, applications, projects, installers, maintenance, disk, health, history, utilities, operation
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .home: "house"; case .cleanup: "pawprint"; case .deepClean: "sparkles"
        case .applications: "app.badge"; case .projects: "hammer"; case .installers: "shippingbox"
        case .maintenance: "stethoscope"; case .disk: "chart.pie"; case .health: "heart.text.clipboard"
        case .history: "clock.arrow.circlepath"; case .utilities: "slider.horizontal.3"; case .operation: "play.rectangle"
        }
    }
}

@MainActor @Observable
final class AppStore {
    let mole = MoleStore()
    let installers = InstallerStore()
    let maintenance = MaintenanceStore()
    let projects = ProjectStore()
    let deepClean = DeepCleanStore()
    let uninstall = UninstallStore()
    let cli = CLIStore()
    var page: Page = .home
    var language = UserDefaults.standard.string(forKey: "language") ?? "zh" {
        didSet { UserDefaults.standard.set(language, forKey: "language") }
    }
    var appearance = UserDefaults.standard.string(forKey: "appearance") ?? "system" {
        didSet { UserDefaults.standard.set(appearance, forKey: "appearance") }
    }
    var report: ScanReport?
    var scanning = false
    var scanPath = ""
    var selected: Set<String> = []
    var category: CleanupCategory?
    var search = ""
    var reviewVisible = false
    var reviewItems: [CleanupItem] = []
    var reviewResults: [String: EngineResult] = [:]
    var reviewing = false
    var cleaning = false
    var operationStatus = ""
    var history: [HistoryEvent] = []
    var message: String?
    var diskFree: Int64 = 0
    var diskTotal: Int64 = 0
    var diskAvailable = false
    var folder: URL?
    var diskReport: DiskReport?
    var inspecting = false
    private var scanToken: CancellationToken?
    private var diskToken: CancellationToken?
    private var operationToken: CancellationToken?
    private var scanGeneration = UUID()
    private var diskGeneration = UUID()
    private let repository = HistoryRepository()
    private let home = FileManager.default.homeDirectoryForCurrentUser
    var busy: Bool { scanning || reviewing || cleaning || mole.operationActive || installers.busy || mole.loadingApps || maintenance.busy || projects.busy || deepClean.scanning || uninstall.loading }
    var scheme: ColorScheme? { appearance == "light" ? .light : appearance == "dark" ? .dark : nil }
    var picked: [CleanupItem] { (report?.items ?? []).filter { selected.contains($0.id) } }
    var selectedBytes: Int64 { picked.reduce(0) { $0 + $1.bytes } }
    var readyItems: [CleanupItem] { reviewItems.filter { reviewResults[$0.id]?.success == true } }
    var readyBytes: Int64 { readyItems.reduce(0) { $0 + $1.bytes } }
    var engine: EngineClient {
        EngineClient(bridge: Bundle.main.resourceURL!.appendingPathComponent("engine/pawly-bridge.sh"))
    }

    init() {
        do { history = try repository.load() }
        catch { message = "無法讀取清理紀錄 / Could not read history: \(error.localizedDescription)" }
        refreshDisk()
    }
    var waitingForShutdown: Bool { busy || inspecting || mole.loadingDisk || mole.loadingHistory || mole.healthCollecting || cli.loading }
    func cancelAllWork() {
        scanToken?.cancel(); diskToken?.cancel(); operationToken?.cancel()
        installers.cancel(); maintenance.cancel(); projects.cancel(); deepClean.cancel(); uninstall.cancel(); mole.cancelAllWork()
        cli.cancel()
        OperationConsole.Coordinator.stopAll()
    }
    func t(_ zh: String, _ en: String) -> String { language == "zh" ? zh : en }
    func title(_ page: Page) -> String {
        switch page {
        case .home: t("小窩總覽", "My Mac")
        case .cleanup: t("快速整理", "Quick cleanup")
        case .deepClean: t("深層清理", "Deep clean")
        case .applications: t("應用程式", "Applications")
        case .projects: t("開發專案", "Projects")
        case .installers: t("安裝檔", "Installers")
        case .maintenance: t("系統維護", "Maintenance")
        case .health: t("健康狀態", "Health")
        case .utilities: t("工具與設定", "Tools")
        case .operation: t("操作工作台", "Operation")
        case .disk: t("空間探索", "Space explorer")
        case .history: t("清理紀錄", "History")
        }
    }
    func openOperation(_ action: EngineAction, target: String? = nil) {
        guard !busy else { return }
        mole.prepare(action, target: target)
        if let error = mole.launchError { message = error } else { page = .operation }
    }
    func record(moved: [String], bytes: Int64, failures: [String]) {
        guard !moved.isEmpty || !failures.isEmpty else { return }
        history.insert(HistoryEvent(moved: moved, bytes: bytes, failed: failures), at: 0)
        do { try repository.save(history) }
        catch { message = error.localizedDescription }
        refreshDisk()
    }
    func openReviewedMaintenance() {
        guard !busy, maintenance.canExecute else { return }
        let tasks = maintenance.picked
        mole.prepare(.optimize, target: tasks.map(\.id).joined(separator: ","))
        mole.acceptMaintenancePreview(tasks.map { maintenance.title($0, zh: language == "zh") }.joined(separator: "\n"))
        page = .operation
    }
    func openReviewedDeepClean() {
        guard !busy, deepClean.canProceed, let report = deepClean.report else { return }
        mole.prepare(.deepClean)
        mole.acceptDeepCleanPreview(t("已檢視 \(report.items.count) 個預覽項目。執行時會重新掃描完整清理範圍；若授予管理員權限，會加入系統項目。", "Reviewed \(report.items.count) preview items. Execution rescans the full cleanup scope; administrator authorization can add system items."))
        page = .operation
    }
    func openReviewedUninstall() {
        guard !busy, let report = uninstall.report else { return }
        mole.prepare(.uninstall, target: report.path)
        guard mole.pendingIdentity == report.identity else { uninstall.error = t("App 已變更，請重新檢查。", "App changed. Review again."); return }
        mole.acceptUninstallPreview(report.files.map(\.path).joined(separator: "\n"))
        uninstall.visible = false; page = .operation
    }
    func title(_ category: CleanupCategory) -> String {
        switch category { case .caches: t("應用程式快取", "App caches"); case .logs: t("舊記錄檔", "Old log files"); case .installers: t("下載的安裝檔", "Old installers") }
    }
    func subtitle(_ category: CleanupCategory) -> String {
        switch category {
        case .caches: t("檢視暫存資料；清理前請關閉相關程式", "Review temporary app data. Close the app first.")
        case .logs: t("14 天未更新的 .log 檔案", "Individual .log files unchanged for 14 days")
        case .installers: t("下載資料夾內，超過 7 天的 DMG 及 PKG", "DMG and PKG downloads older than 7 days")
        }
    }
    func items(_ category: CleanupCategory) -> [CleanupItem] { (report?.items ?? []).filter { $0.category == category } }
    func toggle(_ item: CleanupItem) {
        if selected.contains(item.id) { selected.remove(item.id) } else { selected.insert(item.id) }
    }
    func refreshDisk() {
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: home.path),
           let total = attrs[.systemSize] as? NSNumber, let free = attrs[.systemFreeSize] as? NSNumber {
            diskTotal = total.int64Value; diskFree = free.int64Value; diskAvailable = true
        }
    }
    func scan() {
        guard !busy else { return }
        let token = CancellationToken()
        scanToken = token
        let generation = UUID()
        scanGeneration = generation
        scanning = true; report = nil; selected.removeAll(); scanPath = t("正在準備…", "Getting ready…")
        let scanner = FileScanner(home: home)
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                scanner.scan(token: token) { path in
                    Task { @MainActor [weak self] in
                        guard let self, self.scanGeneration == generation, self.scanning else { return }
                        self.scanPath = path
                    }
                }
            }.value
            guard scanGeneration == generation else { return }
            report = result; scanning = false; scanToken = nil; refreshDisk()
        }
    }
    func cancelScan() { scanToken?.cancel() }
    func chooseFolder() {
        guard !inspecting else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = false
        panel.prompt = t("分析資料夾", "Explore folder")
        if panel.runModal() == .OK, let url = panel.url { inspect(url) }
    }
    func inspect(_ url: URL) {
        diskToken?.cancel()
        let token = CancellationToken(); diskToken = token
        let generation = UUID(); diskGeneration = generation
        folder = url; inspecting = true; diskReport = nil
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                FileScanner().inspect(url, token: token)
            }.value
            guard diskGeneration == generation else { return }
            diskReport = result; inspecting = false; diskToken = nil
        }
    }
    func cancelInspection() { diskToken?.cancel() }
    func reveal(_ url: URL) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
    func openTrash() { NSWorkspace.shared.open(URL(fileURLWithPath: home.path + "/.Trash")) }
    func startReview() {
        guard !busy, !picked.isEmpty else { return }
        reviewItems = picked; reviewResults = [:]; reviewVisible = true; reviewing = true
        let token = CancellationToken(); operationToken = token
        let client = engine
        let plan = reviewItems
        Task {
            let deadline = Date().addingTimeInterval(120)
            for item in plan {
                guard !token.isCancelled, Date() < deadline else { break }
                operationStatus = item.name
                let result = await Task.detached { client.perform(item, preview: true, token: token) }.value
                reviewResults[item.id] = result
            }
            reviewing = false; operationStatus = ""
        }
    }
    func cancelReview() { operationToken?.cancel() }
    func cleanConfirmed() {
        guard !reviewing, !cleaning, !readyItems.isEmpty else { return }
        let plan = readyItems
        let client = engine
        let token = CancellationToken(); operationToken = token
        cleaning = true
        Task {
            var moved: [String] = []; var failures: [String] = []; var bytes: Int64 = 0
            let deadline = Date().addingTimeInterval(180)
            for item in plan {
                guard !token.isCancelled, Date() < deadline else {
                    failures.append(t("餘下項目未處理；操作已停止。", "Remaining items were not processed; operation stopped.")); break
                }
                operationStatus = item.name
                let result = await Task.detached { client.perform(item, preview: false, token: token) }.value
                if result.success {
                    moved.append(item.id); bytes += item.bytes; selected.remove(item.id)
                    report?.items.removeAll { $0.id == item.id }
                } else {
                    failures.append(item.name + ": " + result.detail)
                    // Fail closed for the rest of this batch; no stale authorization reuse.
                    break
                }
            }
            if !moved.isEmpty || !failures.isEmpty {
                history.insert(HistoryEvent(moved: moved, bytes: bytes, failed: failures), at: 0)
                do { try repository.save(history) }
                catch { message = t("紀錄未能儲存：", "History could not be saved: ") + error.localizedDescription }
            }
            cleaning = false; reviewVisible = false; operationStatus = ""; page = .history
            refreshDisk()
        }
    }
}
