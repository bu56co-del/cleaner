import SwiftUI
import PawlyCore

struct CombinedHistoryView: View {
    @Bindable var store: AppStore
    @Bindable var mole: MoleStore
    @State private var source = "pawly"
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker(store.t("紀錄來源", "History source"), selection: $source) {
                    Text(store.t("Pawly 快速整理", "Pawly quick cleanup")).tag("pawly")
                    Text(store.t("完整 Mole 引擎", "Mole engine")).tag("mole")
                }.pickerStyle(.segmented).frame(width: 400)
                Spacer()
                if source == "mole" { Button(store.t("更新", "Refresh")) { mole.refreshHistory() }.disabled(mole.loadingHistory) }
            }.padding(.horizontal, 28).padding(.top, 15)
            if source == "pawly" { HistoryView(store: store) }
            else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PageHeading(title: store.t("清理紀錄", "History"), subtitle: store.t("讀取 Mole 原本的操作與刪除紀錄，最多 100 筆。", "Read up to 100 entries from Mole's operation and deletion logs."))
                        if mole.loadingHistory { ProgressView() }
                        if let error = mole.historyError { InlineError(text: error) }
                        if let history = mole.originalHistory {
                            Text(store.t("操作紀錄", "Operations")).font(.system(size: 17, weight: .semibold, design: .rounded))
                            if history["sessions"].array.isEmpty { Text(store.t("暫時未有操作紀錄。", "No operations recorded yet.")).foregroundStyle(Palette.muted) }
                            ForEach(Array(history["sessions"].array.enumerated()), id: \.offset) { _, session in
                                HStack(alignment: .top, spacing: 16) {
                                    IconTile(icon: "pawprint", color: Palette.sage, tint: Palette.sageTint)
                                    VStack(alignment: .leading, spacing: 7) {
                                        Text(commandTitle(session["command"].display)).fontWeight(.semibold)
                                        Text(session["started_at"].display).font(.system(size: 11)).foregroundStyle(Palette.muted)
                                        HStack(spacing: 16) {
                                            ForEach(["removed", "trashed", "skipped", "failed", "rebuilt"], id: \.self) { key in
                                                if let count = session["actions"][key].number, count > 0 {
                                                    Text(actionTitle(key) + " " + String(Int(count))).foregroundStyle(key == "failed" ? Palette.coral : Palette.muted)
                                                }
                                            }
                                        }.font(.system(size: 11))
                                    }
                                    Spacer()
                                    if let size = session["size"].string, !size.isEmpty { Text(size).foregroundStyle(Palette.sage) }
                                }.padding(18).pawCard()
                            }
                            Text(store.t("檔案處理紀錄", "File activity")).font(.system(size: 17, weight: .semibold, design: .rounded)).padding(.top, 6)
                            if history["deletions"].array.isEmpty { Text(store.t("暫時未有檔案處理紀錄。", "No file activity recorded yet.")).foregroundStyle(Palette.muted) }
                            ForEach(Array(history["deletions"].array.enumerated()), id: \.offset) { _, deletion in
                                HStack(alignment: .top, spacing: 13) {
                                    Image(systemName: deletion["mode"].string == "trash" ? "trash" : "doc").foregroundStyle(Palette.lavender)
                                    VStack(alignment: .leading, spacing: 7) {
                                        Text(deletion["path"].display).font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                                        Text(deletion["timestamp"].display + " · " + deletion["mode"].display + " · " + deletion["status"].display).font(.system(size: 10)).foregroundStyle(Palette.muted)
                                    }.frame(maxWidth: .infinity, alignment: .leading)
                                    if let size = deletion["size_kb"].number { Text(FileSize.string(Int64(size * 1024))).font(.system(size: 11)) }
                                }.padding(16).pawCard()
                            }
                            DisclosureGroup(store.t("紀錄檔位置", "Log locations")) { MetricDetails(value: history["logs"], zh: store.language == "zh") }.font(.system(size: 11)).foregroundStyle(Palette.muted)
                        }
                    }.padding(28)
                }.task { mole.refreshHistory() }
            }
        }
    }
    private func commandTitle(_ value: String) -> String {
        switch value {
        case "clean": store.t("深層清理", "Deep clean")
        case "purge": store.t("專案產物清理", "Project cleanup")
        case "uninstall": store.t("移除應用程式", "Uninstall apps")
        case "optimize": store.t("系統維護", "Maintenance")
        case "installer": store.t("安裝檔整理", "Installer cleanup")
        default: value
        }
    }
    private func actionTitle(_ value: String) -> String {
        switch value {
        case "removed": store.t("已移除", "Removed")
        case "trashed": store.t("已移到垃圾桶", "Trashed")
        case "skipped": store.t("已略過", "Skipped")
        case "failed": store.t("未完成", "Failed")
        case "rebuilt": store.t("已重建", "Rebuilt")
        default: value
        }
    }
}
