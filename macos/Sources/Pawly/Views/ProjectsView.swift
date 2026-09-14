import SwiftUI
import PawlyCore

struct ProjectsView: View {
    @Bindable var store: AppStore
    @Bindable var projects: ProjectStore
    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            PageHeading(title: store.t("開發專案", "Projects"),
                        subtitle: store.t("按專案檢視可重建的產物、大小及近期活動。", "Review rebuildable artifacts, their size and recent activity by project."))
            HStack(spacing: 14) {
                IconTile(icon: "hammer", color: Palette.lavender, tint: Palette.lavenderTint)
                Text(store.t("清理會永久移除確認的產物，之後可能要重新下載依賴或編譯。專案資料夾本身不會被清理。", "Cleanup permanently removes confirmed artifacts and may require downloading dependencies or rebuilding. The project folder itself is kept."))
                    .font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
            }.padding(19).frame(maxWidth: .infinity, alignment: .leading).pawCard()
            HStack {
                Button(store.t("掃描已設定位置", "Scan configured locations")) { projects.scan() }.disabled(store.busy)
                Button(store.t("選擇專案資料夾", "Choose project folder")) { projects.choose() }.disabled(store.busy)
                Button(store.t("管理掃描位置", "Manage locations")) { store.openOperation(.purgePaths) }.disabled(store.busy)
                Spacer()
                if projects.scanning { Button(store.t("停止", "Stop")) { projects.cancel() } }
            }.buttonStyle(.bordered)
            Text(projects.location ?? store.t("設定的專案位置及原引擎自動探索範圍", "Configured locations and engine-discovered projects"))
                .font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted).textSelection(.enabled)
            if let error = projects.error { InlineError(text: error) }
            if let outcome = projects.outcome { Text(outcome).font(.system(size: 12)).foregroundStyle(Palette.sage) }
            if projects.scanning {
                VStack(spacing: 17) { ProgressView(); Text(store.t("搜尋產物、檢查活動並量度大小…", "Finding artifacts, checking activity and measuring sizes…")) }
                    .foregroundStyle(Palette.muted).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let inventory = projects.inventory {
                HStack {
                    TextField(store.t("搜尋專案或產物路徑", "Search projects or artifacts"), text: $projects.search).textFieldStyle(.roundedBorder)
                    Text(store.t("\(inventory.items.count) 個產物", "\(inventory.items.count) artifacts")).foregroundStyle(Palette.muted)
                    Button(store.t("選取較舊項目", "Select older items")) { projects.selected.formUnion(projects.visible.filter { $0.activity == "old" && !$0.cloud && !$0.unknownSize }.map(\.id)) }
                    Button(store.t("清除", "Clear")) { projects.selected = [] }
                }
                if !inventory.complete { InlineError(text: store.t("部分掃描未完成。以下只顯示已取得資料的項目；請選擇較小的資料夾重新掃描。", "Some scans did not complete. Only available results are shown; try scanning a smaller folder.")) }
                List {
                        if inventory.items.isEmpty { Text(store.t("本次未找到可供檢視的編譯產物。", "No build artifacts were found for review.")).foregroundStyle(Palette.muted).padding(25) }
                    ForEach(projects.groups) { group in
                        Section {
                                ForEach(group.items) { item in
                                    HStack(alignment: .top, spacing: 13) {
                                        Toggle("", isOn: Binding(get: { projects.selected.contains(item.id) }, set: { if $0 { projects.selected.insert(item.id) } else { projects.selected.remove(item.id) } }))
                                            .toggleStyle(.checkbox).labelsHidden().accessibilityLabel(item.path)
                                        Image(systemName: "shippingbox").foregroundStyle(Palette.lavender)
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(item.artifact).fontWeight(.medium)
                                            Text(item.path).font(.system(size: 9, design: .monospaced)).foregroundStyle(Palette.muted).lineLimit(2).textSelection(.enabled)
                                            if item.cloud { Text(store.t("雲端同步：移除亦可能同步到其他裝置。", "Cloud-synced: removal may affect other devices.")).font(.system(size: 10)).foregroundStyle(Palette.coral) }
                                        }.frame(maxWidth: .infinity, alignment: .leading)
                                        Text(item.activity == "old" ? store.t("較舊", "Older") : item.activity == "recent" ? store.t("近期使用", "Recently active") : store.t("活動未確認", "Activity unknown"))
                                            .font(.system(size: 10)).foregroundStyle(item.activity == "old" ? Palette.sage : Palette.coral)
                                        Text(item.unknownSize ? store.t("大小未確認", "Unmeasured") : FileSize.string(item.bytes)).font(.system(size: 11, design: .monospaced)).frame(width: 100, alignment: .trailing)
                                        Button { store.reveal(URL(fileURLWithPath: item.path)) } label: { Image(systemName: "arrow.up.right.square") }.buttonStyle(.plain).help(store.t("在 Finder 顯示", "Show in Finder"))
                                    }.padding(.vertical, 7)
                                }
                        } header: {
                                HStack {
                                    Image(systemName: "folder.fill").foregroundStyle(Palette.sage)
                                    Text(group.id).font(.system(size: 12, weight: .semibold)).lineLimit(2).textSelection(.enabled)
                                    Spacer()
                                    Text(FileSize.string(group.bytes)).font(.system(size: 12, design: .rounded)).foregroundStyle(Palette.muted)
                                }.padding(.vertical, 6)
                        }
                    }
                }.listStyle(.inset).scrollContentBackground(.hidden).pawCard()
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(store.t("已選 \(projects.picked.count) 個 · \(FileSize.string(projects.picked.reduce(0) { $0 + $1.bytes }))", "\(projects.picked.count) selected · \(FileSize.string(projects.picked.reduce(0) { $0 + $1.bytes }))")).fontWeight(.semibold)
                        Text(store.t("重新核對所選項目，再確認永久移除。", "Recheck your exact selection before confirming permanent removal.")).font(.system(size: 10)).foregroundStyle(Palette.muted)
                    }
                    Spacer()
                    Button(store.t("檢查所選項目", "Review selection")) { projects.review() }.buttonStyle(PawButtonStyle()).disabled(store.busy || projects.picked.isEmpty || !inventory.complete)
                }
            } else {
                VStack(spacing: 20) { CatMark().frame(width: 70, height: 70); Text(store.t("選擇位置，看看可以收拾甚麼。", "Choose a location and see what can be tidied.")) }
                    .foregroundStyle(Palette.muted).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }.padding(28).sheet(isPresented: $projects.reviewVisible) { reviewSheet }
    }
    private var reviewSheet: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label(store.t("留下創作，整理產物。", "Keep your ideas. Tidy the builds."), systemImage: "pawprint.fill").font(.system(size: 23, weight: .semibold, design: .rounded))
            Text(store.t("以下產物會永久移除，不會移到垃圾桶。之後可能需要重新編譯或下載依賴。", "These artifacts will be permanently removed, without Trash recovery. Rebuilding or downloading dependencies may be needed afterwards.")).font(.system(size: 12)).foregroundStyle(Palette.coral)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(projects.plan) { item in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack { Image(systemName: "shippingbox").foregroundStyle(Palette.lavender); Text(item.path).font(.system(size: 11, design: .monospaced)).textSelection(.enabled); Spacer(); Text(item.unknownSize ? store.t("大小未確認", "Unmeasured") : FileSize.string(item.bytes)) }
                            if item.activity != "old" { Text(store.t("此項目近期使用過或活動未能確認，請確定可以重新建立。", "This artifact is recent or its activity is unknown. Check that you can rebuild it.")).font(.system(size: 11)).foregroundStyle(Palette.coral) }
                            if item.cloud { Text(store.t("雲端同步：其他裝置亦可能失去此項目。", "Cloud sync may remove this item from other devices too.")).font(.system(size: 11)).foregroundStyle(Palette.coral) }
                        }; Divider()
                    }
                }
            }.frame(maxHeight: 330)
            if let error = projects.error { InlineError(text: error) }
            if projects.busy { HStack { ProgressView().controlSize(.small); Text(store.t(projects.cleaning ? "正在整理所選項目…" : "重新檢查路徑、活動及大小…", projects.cleaning ? "Cleaning selected artifacts…" : "Rechecking paths, activity and sizes…")) } }
            else if projects.reviewPassed { Label(store.t("所選項目已通過檢查。", "Your selection passed the checks."), systemImage: "checkmark.circle.fill").foregroundStyle(Palette.sage) }
            HStack {
                if projects.busy { Button(store.t("停止", "Stop")) { projects.cancel() } }
                else { Button(store.t("返回", "Back")) { projects.reviewVisible = false }.keyboardShortcut(.cancelAction) }
                Spacer()
                Button(store.t("永久移除 · \(projects.plan.count)", "Permanently remove · \(projects.plan.count)")) { projects.purgeConfirmed() }.buttonStyle(PawButtonStyle()).disabled(projects.busy || !projects.reviewPassed)
            }
        }.padding(28).frame(width: 730).background(Palette.background).interactiveDismissDisabled(projects.busy)
    }
}
