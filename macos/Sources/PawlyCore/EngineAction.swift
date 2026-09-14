import Foundation

/// Closed command vocabulary. User text can never become an executable/flag.
public enum EngineAction: String, CaseIterable, Sendable, Identifiable {
    case deepClean, uninstall, purge, installer, optimize, analyze
    case cleanWhitelist, optimizeWhitelist, purgePaths, touchID, completion
    case cliUpdate, cliRemove
    public var id: String { rawValue }
    public var supportsPreview: Bool { [.deepClean, .uninstall, .purge, .installer, .optimize, .cliUpdate, .cliRemove].contains(self) }
    public var icon: String {
        switch self {
        case .deepClean: "sparkles"; case .uninstall: "app.badge"; case .purge: "hammer"
        case .installer: "shippingbox"; case .optimize: "stethoscope"; case .analyze: "chart.pie"
        case .cleanWhitelist, .optimizeWhitelist: "shield.lefthalf.filled"
        case .purgePaths: "folder.badge.gearshape"; case .touchID: "touchid"; case .completion: "terminal"
        case .cliUpdate: "arrow.triangle.2.circlepath"; case .cliRemove: "terminal"
        }
    }
    public func title(zh: Bool) -> String {
        switch self {
        case .deepClean: zh ? "深層清理" : "Deep clean"
        case .uninstall: zh ? "移除應用程式" : "Uninstall apps"
        case .purge: zh ? "開發專案清理" : "Project cleanup"
        case .installer: zh ? "安裝檔整理" : "Installer cleanup"
        case .optimize: zh ? "系統維護" : "Maintenance"
        case .analyze: zh ? "互動磁碟探索" : "Interactive disk explorer"
        case .cleanWhitelist: zh ? "清理保留清單" : "Cleanup exclusions"
        case .optimizeWhitelist: zh ? "維護排除清單" : "Maintenance exclusions"
        case .purgePaths: zh ? "專案掃描位置" : "Project locations"
        case .touchID: zh ? "Touch ID 授權" : "Touch ID authorization"
        case .completion: zh ? "指令自動補全" : "Shell completion"
        case .cliUpdate: zh ? "更新已安裝 Mole 指令版" : "Update installed Mole CLI"
        case .cliRemove: zh ? "移除已安裝 Mole 指令版" : "Remove installed Mole CLI"
        }
    }
    public func detail(zh: Bool) -> String {
        switch self {
        case .deepClean: zh ? "掃描使用者、瀏覽器、開發工具、系統及已移除 App 的殘留資料。" : "Review user, browser, developer and system caches, plus leftovers from removed apps."
        case .uninstall: zh ? "檢查 App 與相關檔案；保留仍由其他副本使用的共用資料。" : "Review the app and related files while protecting shared data used by another copy."
        case .purge: zh ? "按專案檢視 node_modules、target、build、dist 等可重新產生的檔案。" : "Review rebuildable node_modules, target, build, dist and other artifacts by project."
        case .installer: zh ? "搜尋下載項目、桌面及其他支援位置的 DMG、PKG、ISO、XIP 和安裝 ZIP。" : "Find DMG, PKG, ISO, XIP and installer ZIP files in Downloads, Desktop and other supported locations."
        case .optimize: zh ? "檢查 DNS、Spotlight、Finder、資料庫及磁碟；不適用的工作會註明並略過。" : "Check DNS, Spotlight, Finder, databases and disks; unavailable or unnecessary tasks are explained and skipped."
        case .analyze: zh ? "逐層瀏覽、搜尋、多選、Finder 預覽及確認移到垃圾桶。" : "Navigate, search, select, preview in Finder and confirm moves to Trash."
        case .cleanWhitelist: zh ? "指定要保留的路徑，深層清理時會略過。" : "Protect paths that the deep cleaner should keep."
        case .optimizeWhitelist: zh ? "排除指定維護工作或路徑。" : "Exclude maintenance tasks or paths."
        case .purgePaths: zh ? "指定專案資料夾，縮小掃描範圍。" : "Choose the project folders to scan."
        case .touchID: zh ? "檢查或設定 sudo 使用 Touch ID；變更時需要管理員授權。" : "Inspect or configure Touch ID for sudo; changes require administrator authorization."
        case .completion: zh ? "管理已安裝 Mole 指令的 shell 自動補全。" : "Manage shell completion for the installed Mole CLI."
        case .cliUpdate: zh ? "先確認目前版本及位置，再由已安裝的 Mole 執行更新。" : "Review the installed version and location, then let that Mole installation update itself."
        case .cliRemove: zh ? "預覽 Mole 偵測到的指令版安裝、設定及紀錄，再確認移除。" : "Preview the CLI installations, configuration and logs detected by Mole before removal."
        }
    }
    public func impact(zh: Bool) -> String {
        switch self {
        case .deepClean: zh ? "完整清理包含永久刪除及清空垃圾桶。請先檢查全部預覽；可用保留清單排除路徑。執行時引擎會重新檢查目標。" : "The full cleanup includes permanent deletion and emptying Trash. Review the complete preview and protect paths with exclusions. The engine rechecks targets at execution."
        case .purge: zh ? "確認的編譯產物會永久刪除；之後可能需要重新安裝依賴或編譯。專案原始碼不屬於清理目標。" : "Confirmed build artifacts are permanently removed and may need dependency installation or rebuilding. Project source is not a cleanup target."
        case .uninstall: zh ? "App 及確認的相關檔案預設移到垃圾桶。可能會停止 App、移除登入項目或透過 Homebrew 處理；部分設定不會隨垃圾桶還原。" : "App files normally move to Trash. The engine may stop apps, remove login items or use Homebrew; those changes are not all restored by Put Back."
        case .installer: zh ? "引擎會列出安裝檔的路徑、大小及來源；最終確認後移除。" : "The engine lists installer paths, sizes and sources before the final removal confirmation."
        case .optimize: zh ? "會按預覽刷新服務、快取或資料庫；系統可能要求授權。請先儲存工作並關閉預覽列出的相關 App。" : "The pass refreshes services, caches or databases and may request authorization. Save your work and close apps named in the preview."
        case .cliUpdate: zh ? "會連線下載並更新下方的獨立 Mole 指令版；Pawly 內附引擎不會被更新。" : "Downloads and updates the separate Mole CLI shown below. Pawly's bundled engine is unchanged."
        case .cliRemove: zh ? "Mole 自我移除可能包括多個指令版安裝及共用設定、快取與紀錄；請先檢查完整預覽。Pawly App 本身會保留。" : "Mole self-removal may include multiple CLI installations and shared settings, caches and logs. Review the full preview. Pawly itself remains installed."
        default: detail(zh: zh)
        }
    }
}

public struct OperationRequest: Identifiable, Sendable {
    public let id = UUID()
    public let action: EngineAction
    public let preview: Bool
    public let target: String?
    public let identity: String?
    public init(action: EngineAction, preview: Bool = true, target: String? = nil, identity: String? = nil) {
        self.action = action; self.preview = preview; self.target = target; self.identity = identity
    }
    public var arguments: [String] {
        [action.rawValue, preview ? "preview" : "run"] + (target.map { [$0, identity ?? ""] } ?? [])
    }
}
