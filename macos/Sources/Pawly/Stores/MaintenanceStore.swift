import SwiftUI
import PawlyCore

@MainActor @Observable
final class MaintenanceStore {
    var tasks: [MaintenanceTask] = []
    var selected: Set<String> = []
    var previews: [String: MaintenancePreview] = [:]
    var errors: [String: String] = [:]
    var loading = false
    var reviewing = false
    var error: String?
    var current: String?
    var search = ""
    private var token: CancellationToken?
    private var reviewedAt: Date?
    private var reviewedSelection: Set<String> = []
    var busy: Bool { loading || reviewing }
    var client: MaintenanceClient { MaintenanceClient(engine: Bundle.main.resourceURL!.appendingPathComponent("engine")) }
    var visible: [MaintenanceTask] { tasks.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || $0.detail.localizedCaseInsensitiveContains(search) || title($0, zh: true).localizedCaseInsensitiveContains(search) || detail($0, zh: true).localizedCaseInsensitiveContains(search) } }
    var picked: [MaintenanceTask] { tasks.filter { selected.contains($0.id) && !$0.excluded } }
    var canExecute: Bool {
        !busy && !selected.isEmpty && selected == reviewedSelection && errors.isEmpty &&
        reviewedAt.map { Date().timeIntervalSince($0) < 600 } == true &&
        picked.count == selected.count && picked.allSatisfy { previews[$0.id]?.allowsExecution == true }
    }
    func refresh() {
        guard !busy else { return }
        let token = CancellationToken(); self.token = token; let client = client
        loading = true; error = nil; selected = []; invalidateReview()
        Task {
            do { tasks = try await Task.detached { try client.catalog(token: token) }.value }
            catch { self.error = error.localizedDescription }
            loading = false
        }
    }
    func toggle(_ task: MaintenanceTask, enabled: Bool) {
        guard !busy, !task.excluded else { return }
        if enabled { selected.insert(task.id) } else { selected.remove(task.id) }
        invalidateReview()
    }
    func selectVisible(_ enabled: Bool) {
        guard !busy else { return }
        if enabled { selected.formUnion(visible.filter { !$0.excluded }.map(\.id)) }
        else { selected = [] }
        invalidateReview()
    }
    private func invalidateReview() { reviewedAt = nil; reviewedSelection = []; previews = [:]; errors = [:] }
    func cancel() { token?.cancel(); reviewedAt = nil }
    func preview() {
        guard !busy, !picked.isEmpty else { return }
        invalidateReview(); error = nil; reviewing = true
        let actions = picked; let token = CancellationToken(); self.token = token; let client = client
        Task {
            let deadline = Date().addingTimeInterval(300)
            for action in actions {
                guard !token.isCancelled, Date() < deadline else { break }
                current = action.id
                do { previews[action.id] = try await Task.detached { try client.preview(action.id, token: token) }.value }
                catch { errors[action.id] = error.localizedDescription }
            }
            if !token.isCancelled, previews.count == actions.count, errors.isEmpty {
                reviewedSelection = Set(actions.map(\.id)); reviewedAt = Date()
            } else if errors.isEmpty { error = "預覽未完成；請重新預覽。 / Preview incomplete. Run it again." }
            current = nil; reviewing = false
        }
    }
    func title(_ task: MaintenanceTask, zh: Bool) -> String {
        guard zh else { return task.name }
        let names = ["system_maintenance": "DNS 與 Spotlight 檢查", "cache_refresh": "Finder 快取更新",
            "saved_state_cleanup": "舊 App 狀態整理", "fix_broken_configs": "損壞偏好設定修復",
            "network_optimization": "網絡快取更新", "sqlite_vacuum": "資料庫整理", "launch_services_rebuild": "開啟方式與檔案關聯",
            "prevent_network_dsstore": "停止外置磁碟 .DS_Store", "legacy_overrides_audit": "舊調校設定檢查",
            "network_stack_optimize": "網絡路由更新", "disk_permissions_repair": "個人資料夾權限修復",
            "spotlight_index_optimize": "Spotlight 索引維護", "spotlight_orphan_rules_cleanup": "失效搜尋規則整理",
            "periodic_maintenance": "macOS 定期維護", "shared_file_list_repair": "Finder 常用項目修復",
            "disk_verify": "磁碟完整性檢查", "login_items_audit": "登入項目檢查", "quarantine_cleanup": "下載追蹤紀錄整理",
            "launch_agents_cleanup": "失效背景啟動項目", "notification_cleanup": "舊通知整理", "coreduet_cleanup": "舊使用紀錄整理"]
        return names[task.id] ?? task.name
    }
    func detail(_ task: MaintenanceTask, zh: Bool) -> String {
        guard zh else { return task.detail }
        let details = [
            "system_maintenance": "更新 DNS 快取，並檢查 Spotlight 搜尋服務狀態。",
            "cache_refresh": "更新 QuickLook 預覽縮圖及應用程式圖示快取。",
            "saved_state_cleanup": "整理超過 30 天的應用程式視窗狀態紀錄。",
            "fix_broken_configs": "檢查並處理損壞的偏好設定；保留受保護及已排除的檔案。",
            "network_optimization": "更新 DNS 快取，並在需要時重新啟動名稱查詢服務。",
            "sqlite_vacuum": "整理 Mail、Safari 及 Messages 資料庫；相關 App 使用中會略過。",
            "launch_services_rebuild": "重建「開啟方式」選單及檔案與應用程式的關聯。",
            "prevent_network_dsstore": "更改 Finder 偏好設定，停止在網絡及 USB 磁碟寫入 .DS_Store。",
            "legacy_overrides_audit": "檢查舊調校工具留下的 App Nap 及磁碟映像驗證設定。",
            "network_stack_optimize": "更新路由及 ARP 快取以排查連線問題，可能短暫影響網絡。",
            "disk_permissions_repair": "檢查並修復個人資料夾的權限問題。",
            "spotlight_index_optimize": "檢查搜尋速度及索引狀態，必要時重建 Spotlight 索引。",
            "spotlight_orphan_rules_cleanup": "整理仍指向已移除應用程式的 Spotlight 搜尋規則。",
            "periodic_maintenance": "檢查 macOS 每日、每週及每月維護工作，過期時才執行。",
            "shared_file_list_repair": "檢查並修復損壞的 Finder 常用項目及最近使用紀錄。",
            "disk_verify": "原引擎預設停用：APFS 異常時，完整磁碟驗證可能令系統失去回應。預覽會列明略過原因。",
            "login_items_audit": "檢查登入項目有沒有指向已不存在的應用程式。",
            "quarantine_cleanup": "整理 Gatekeeper 記錄的下載追蹤歷史。",
            "launch_agents_cleanup": "檢查背景啟動項目，只處理已確認不存在的程式路徑。",
            "notification_cleanup": "整理已送達的舊通知紀錄。",
            "coreduet_cleanup": "整理支援的舊使用活動紀錄。"
        ]
        return details[task.id] ?? task.detail
    }
}
