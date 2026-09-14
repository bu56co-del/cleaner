import SwiftUI
import PawlyCore

struct MaintenanceView: View {
    @Bindable var store: AppStore
    @Bindable var maintenance: MaintenanceStore
    @State private var expanded: Set<String> = []
    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            PageHeading(title: store.t("系統維護", "Maintenance"),
                        subtitle: store.t("選擇維護項目，先睇每項預覽，再決定執行。", "Choose tasks, review each preview, then decide what to run."))
            HStack(spacing: 16) {
                CatMark().frame(width: 51, height: 51)
                VStack(alignment: .leading, spacing: 6) {
                    Text(store.t("\(maintenance.tasks.count) 項維護，由你決定", "\(maintenance.tasks.count) tasks. You're in charge.")).font(.system(size: 18, weight: .semibold, design: .rounded))
                    Text(store.t("可能更新服務、偏好設定或資料庫；需要時會另外要求管理員授權。", "Tasks may change services, preferences or databases. Administrator access is requested separately when needed."))
                        .font(.system(size: 11)).foregroundStyle(Palette.muted)
                }
                Spacer()
                Button(store.t("排除清單", "Exclusions")) { store.openOperation(.optimizeWhitelist) }.disabled(store.busy)
            }.padding(18).pawCard()
            HStack {
                TextField(store.t("搜尋維護項目", "Search maintenance"), text: $maintenance.search).textFieldStyle(.roundedBorder)
                Button(store.t("重新載入", "Reload")) { maintenance.refresh() }.disabled(store.busy)
                Button(store.t("全選搜尋結果", "Select results")) { maintenance.selectVisible(true) }.disabled(store.busy)
                Button(store.t("取消選取", "Clear")) { maintenance.selectVisible(false) }.disabled(store.busy)
            }.buttonStyle(.bordered)
            if let error = maintenance.error { InlineError(text: error) }
            if maintenance.loading { ProgressView().frame(maxWidth: .infinity) }
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(maintenance.visible) { task in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top, spacing: 13) {
                                Toggle("", isOn: Binding(get: { maintenance.selected.contains(task.id) }, set: { maintenance.toggle(task, enabled: $0) }))
                                    .labelsHidden().toggleStyle(.checkbox).disabled(store.busy || task.excluded)
                                    .accessibilityLabel(maintenance.title(task, zh: store.language == "zh"))
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(maintenance.title(task, zh: store.language == "zh")).fontWeight(.semibold)
                                    Text(maintenance.detail(task, zh: store.language == "zh")).font(.system(size: 11)).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                if task.excluded { Text(store.t("已排除", "Excluded")).foregroundStyle(Palette.muted).font(.system(size: 10)) }
                                if maintenance.current == task.id { ProgressView().controlSize(.small) }
                                if let result = maintenance.previews[task.id] {
                                    Text(outcome(result.outcome)).font(.system(size: 10, weight: .medium)).foregroundStyle(result.allowsExecution ? Palette.sage : Palette.coral)
                                    Button { if !expanded.insert(task.id).inserted { expanded.remove(task.id) } } label: { Image(systemName: expanded.contains(task.id) ? "chevron.up" : "chevron.down") }
                                        .buttonStyle(.plain).help(store.t("預覽詳情", "Preview details"))
                                }
                            }
                            if expanded.contains(task.id), let result = maintenance.previews[task.id] {
                                Text(result.detail.trimmingCharacters(in: .whitespacesAndNewlines)).font(.system(size: 11, design: .monospaced))
                                    .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(13).background(Palette.background, in: RoundedRectangle(cornerRadius: 4))
                            }
                            if let error = maintenance.errors[task.id] { InlineError(text: error) }
                        }.padding(17)
                        Divider()
                    }
                }
            }.pawCard()
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.t("已選 \(maintenance.picked.count) 項", "\(maintenance.picked.count) selected")).fontWeight(.semibold)
                    Text(store.t("預覽不作系統變更；執行會重新檢查現況。", "Preview makes no system changes; execution rechecks current conditions.")).font(.system(size: 10)).foregroundStyle(Palette.muted)
                }
                Spacer()
                if maintenance.busy {
                    Button(store.t("停止", "Stop")) { maintenance.cancel() }.buttonStyle(PawButtonStyle(prominent: false))
                } else {
                    Button(store.t("預覽所選項目", "Preview selected")) { maintenance.preview() }.buttonStyle(PawButtonStyle(prominent: false)).disabled(store.busy || maintenance.picked.isEmpty)
                    Button(store.t("查看執行確認", "Review execution")) { store.openReviewedMaintenance() }.buttonStyle(PawButtonStyle()).disabled(store.busy || !maintenance.canExecute)
                }
            }
        }.padding(28).task { if maintenance.tasks.isEmpty && !maintenance.busy { maintenance.refresh() } }
    }
    private func outcome(_ value: String) -> String {
        switch value {
        case "applied": store.t("預計會變更", "Would change")
        case "unchanged": store.t("無需變更", "No change needed")
        case "skipped": store.t("略過", "Skipped")
        case "unavailable": store.t("未能使用", "Unavailable")
        case "attention": store.t("需要留意", "Needs attention")
        default: store.t("預覽失敗", "Preview failed")
        }
    }
}
