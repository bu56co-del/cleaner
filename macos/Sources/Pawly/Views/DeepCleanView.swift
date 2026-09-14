import SwiftUI
import PawlyCore

struct DeepCleanView: View {
    @Bindable var store: AppStore
    @Bindable var clean: DeepCleanStore
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeading(title: store.t("深層清理", "Deep clean"), subtitle: store.t("使用 Mole 完整掃描，按分類檢視清理預覽。", "Review the full Mole cleanup preview, organized by category."))
            HStack(spacing: 17) {
                CatMark().frame(width: 48, height: 48)
                Text(EngineAction.deepClean.impact(zh: store.language == "zh")).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading).pawCard()
            HStack {
                Button(store.t(clean.scanning ? "停止" : "掃描清理項目", clean.scanning ? "Stop" : "Preview deep clean")) { if clean.scanning { clean.cancel() } else { clean.scan() } }.buttonStyle(PawButtonStyle()).disabled(store.busy && !clean.scanning)
                Button(store.t("管理保留清單", "Manage exclusions")) { store.openOperation(.cleanWhitelist) }.disabled(store.busy)
                Button(store.t("外置磁碟", "External volume")) {
                    let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = false
                    panel.directoryURL = URL(fileURLWithPath: "/Volumes")
                    panel.begin { response in if response == .OK, let url = panel.url { store.openOperation(.deepClean, target: url.path) } }
                }.disabled(store.busy)
                Spacer()
            }
            if let error = clean.error { InlineError(text: error) }
            if clean.scanning && clean.report == nil {
                VStack(spacing: 18) { ProgressView(); Text(store.t("正在檢查使用者、瀏覽器、開發工具及 App 殘留…", "Checking user files, browsers, developer tools and app leftovers…")); Text(store.t("完整掃描可能需時數分鐘，可以隨時停止。", "A full preview can take a few minutes. You can stop at any time.")).font(.system(size: 11)) }.foregroundStyle(Palette.muted).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let report = clean.report {
                if clean.scanning { HStack { ProgressView().controlSize(.small); Text(store.t("繼續掃描其他分類；以下是已完成的部分。", "Scanning remaining categories; completed results appear below.")).font(.system(size: 11)).foregroundStyle(Palette.muted) } }
                HStack {
                    Text(FileSize.string(clean.measuredBytes)).font(.system(size: 28, weight: .semibold, design: .rounded)).foregroundStyle(Palette.sage)
                    Text(store.t("已量度 · \(report.items.count) 個預覽項目", "measured · \(report.items.count) preview items")).foregroundStyle(Palette.muted)
                    Spacer()
                }
                if !report.complete && !clean.scanning { InlineError(text: store.t("部分掃描未完成；請重新掃描，或在操作工作台查看完整輸出。", "The preview is incomplete. Scan again or view full output in the operation workspace.")) }
                if !report.systemIncluded { Text(store.t("目前預覽不包括需要管理員權限的系統項目。", "This preview excludes system items requiring administrator access.")).font(.system(size: 11)).foregroundStyle(Palette.muted) }
                TextField(store.t("搜尋分類或路徑", "Search categories or paths"), text: $clean.search).textFieldStyle(.roundedBorder)
                List {
                        ForEach(clean.groups) { group in
                            Section {
                                ForEach(group.items) { item in
                                    HStack(alignment: .top) {
                                        Text(item.path).font(.system(size: 11, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                                        Text(item.known ? FileSize.string(item.bytes) : store.t("大小未確認", "Unmeasured")).font(.system(size: 11, design: .monospaced))
                                    }.padding(.vertical, 6)
                                }
                            } header: { Text(group.id).fontWeight(.semibold).foregroundStyle(Palette.sage) }
                        }
                }.listStyle(.inset).scrollContentBackground(.hidden).pawCard()
                HStack {
                    Text(store.t("這是完整清理的預覽；要保留個別路徑，先加入保留清單再重掃。", "This previews the full pass. Add paths to exclusions and rescan to keep individual items.")).font(.system(size: 11)).foregroundStyle(Palette.muted)
                    Spacer()
                    Button(store.t("前往清理確認…", "Continue to confirmation…")) { store.openReviewedDeepClean() }.buttonStyle(PawButtonStyle()).disabled(store.busy || !clean.canProceed)
                }
            } else {
                VStack(spacing: 15) { Mascot().frame(width: 190, height: 190); Text(store.t("先看看完整清單，再決定。", "See the complete preview before you decide.")) }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Button(store.t("開啟原引擎完整操作", "Open full engine workflow")) { store.openOperation(.deepClean) }.font(.system(size: 11)).buttonStyle(.plain).foregroundStyle(Palette.muted).disabled(store.busy)
        }.padding(28)
    }
}
