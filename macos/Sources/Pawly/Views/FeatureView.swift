import SwiftUI
import PawlyCore

struct FeatureView: View {
    @Bindable var store: AppStore
    let action: EngineAction
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                PageHeading(title: action.title(zh: store.language == "zh"), subtitle: action.detail(zh: store.language == "zh"))
                HStack(spacing: 25) {
                    VStack(alignment: .leading, spacing: 20) {
                        IconTile(icon: action.icon, color: Palette.sage, tint: Palette.sageTint)
                        Text(headline).font(.system(size: 27, weight: .semibold, design: .rounded))
                        Text(action.impact(zh: store.language == "zh")).font(.system(size: 12)).lineSpacing(5)
                        Button { store.openOperation(action) } label: { Label(store.t("預覽與整理", "Preview & review"), systemImage: "pawprint.fill") }
                            .buttonStyle(PawButtonStyle()).disabled(store.busy)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Mascot().frame(width: 210, height: 210)
                }.padding(26).pawCard()
                ForEach(features, id: \.0) { title, detail, icon in
                    HStack(spacing: 16) {
                        Image(systemName: icon).font(.system(size: 21)).foregroundStyle(Palette.lavender).frame(width: 32)
                        VStack(alignment: .leading, spacing: 6) { Text(title).fontWeight(.semibold); Text(detail).font(.system(size: 12)).foregroundStyle(Palette.muted) }
                        Spacer()
                    }.padding(19).pawCard()
                }
                HStack {
                    if action == .deepClean { auxiliary(.cleanWhitelist) }
                    if action == .optimize { auxiliary(.optimizeWhitelist) }
                    if action == .purge { auxiliary(.purgePaths) }
                    if action == .deepClean {
                        Button(store.t("外置磁碟清理", "External volume cleanup")) {
                            let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false
                            panel.directoryURL = URL(fileURLWithPath: "/Volumes")
                            if panel.runModal() == .OK, let url = panel.url { store.openOperation(.deepClean, target: url.path) }
                        }.buttonStyle(PawButtonStyle(prominent: false)).disabled(store.busy)
                    }
                }
            }.padding(28)
        }
    }
    private var headline: String {
        switch action {
        case .deepClean: store.t("每個角落，都照顧到。", "A little care for every corner.")
        case .purge: store.t("留低創作，整理產物。", "Keep the ideas. Tidy the builds.")
        case .installer: store.t("安裝完成，就收拾一下。", "Installed it? Let's tidy up.")
        default: store.t("給你的 Mac，一點照顧。", "A little care for your Mac.")
        }
    }
    private var features: [(String, String, String)] {
        switch action {
        case .deepClean:
            [(store.t("使用者與瀏覽器", "User & browsers"), store.t("快取、記錄、暫存及支援的瀏覽器資料。", "Caches, logs, temporary files and supported browser caches."), "person.crop.circle"),
             (store.t("開發工具與 App 殘留", "Developer tools & leftovers"), store.t("使用原引擎的路徑保護、程式使用中檢查及保留清單。", "Uses the engine's path protection, activity checks and exclusions."), "wrench.and.screwdriver"),
             (store.t("系統與外置磁碟", "System & external disks"), store.t("需要授權的項目會由引擎另行提示；不會自動提升權限。", "The engine prompts separately for actions requiring authorization."), "externaldrive")]
        case .purge:
            [(store.t("按專案分組", "Grouped by project"), store.t("逐個檢查產物路徑、大小及活動時間。", "Review each artifact's path, size and activity age."), "folder"),
             (store.t("近期使用項目", "Recent activity"), store.t("最近 7 天有活動或無法確認的項目，預設不勾選。", "Artifacts active within 7 days, or with unknown activity, start unselected."), "clock"),
             (store.t("保留專案本身", "Keep the project"), store.t("只處理選取的重建產物，不刪整個 Git worktree。", "Remove selected rebuildable artifacts, never whole Git worktrees."), "shield")]
        case .installer:
            [(store.t("完整安裝格式", "Supported formats"), "DMG · PKG · MPKG · ISO · XIP · ZIP", "shippingbox"),
             (store.t("多個來源位置", "Multiple locations"), store.t("下載項目、桌面、Homebrew、iCloud 及支援的通訊軟件目錄。", "Downloads, Desktop, Homebrew, iCloud and supported messaging folders."), "tray.full"),
             (store.t("逐項檢查", "Review every item"), store.t("檢查來源、完整路徑及大小，最後才確認移除。", "Check source, full path and size before confirming removal."), "checklist")]
        default:
            [(store.t("DNS 與搜尋索引", "DNS & search index"), store.t("檢查網絡快取及 Spotlight 索引。", "Check network caches and Spotlight indexing."), "magnifyingglass"),
             (store.t("Finder 與資料庫", "Finder & databases"), store.t("依目前狀態刷新支援的服務與資料庫。", "Refresh supported services and databases as appropriate."), "macwindow"),
             (store.t("逐項結果", "Per-task results"), store.t("顯示已執行、無需變更、略過或不可用及原因。", "Reports applied, unchanged, skipped or unavailable tasks with reasons."), "list.bullet.clipboard")]
        }
    }
    private func auxiliary(_ action: EngineAction) -> some View {
        Button(action.title(zh: store.language == "zh")) { store.openOperation(action) }.buttonStyle(PawButtonStyle(prominent: false)).disabled(store.busy)
    }
}
