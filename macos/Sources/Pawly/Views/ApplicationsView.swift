import SwiftUI
import PawlyCore

struct ApplicationsView: View {
    @Bindable var store: AppStore
    @Bindable var mole: MoleStore
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeading(title: store.t("應用程式", "Applications"),
                        subtitle: store.t("檢視已安裝的 App，連相關檔案一齊確認。", "Review installed apps and their related files before removal."))
            HStack {
                TextField(store.t("搜尋名稱、Bundle ID 或路徑", "Search name, bundle ID or path"), text: $mole.appSearch).textFieldStyle(.roundedBorder)
                Picker("", selection: $mole.appSource) {
                    Text(store.t("全部來源", "All sources")).tag("all")
                    Text("App").tag("App"); Text("Homebrew").tag("Homebrew")
                }.frame(width: 155)
                Button(store.t(mole.loadingApps ? "停止" : "重新掃描", mole.loadingApps ? "Stop" : "Refresh")) {
                    if mole.loadingApps { mole.cancelApps() } else { mole.refreshApps() }
                }.disabled(mole.operationActive).buttonStyle(PawButtonStyle(prominent: false))
            }
            if let error = mole.appError { InlineError(text: error) }
            if mole.loadingApps {
                VStack(spacing: 16) { ProgressView(); Text(store.t("正在檢查應用程式及大小…", "Reading apps and their sizes…")) }
                    .foregroundStyle(Palette.muted).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HSplitView {
                    List(mole.visibleApps, selection: $mole.appSelection) { app in
                        HStack(spacing: 11) {
                            AppIcon(path: app.path, size: 34)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(app.name).fontWeight(.medium)
                                Text(app.bundleID.isEmpty ? app.source : app.bundleID).font(.system(size: 10)).foregroundStyle(Palette.muted).lineLimit(1)
                            }
                            Spacer(); Text(app.size).font(.system(size: 11, design: .monospaced)).foregroundStyle(Palette.muted)
                        }.padding(.vertical, 5).tag(app.id)
                    }.listStyle(.inset).frame(minWidth: 300)
                    if let app = mole.pickedApp {
                        VStack(alignment: .leading, spacing: 18) {
                            AppIcon(path: app.path, size: 72)
                            Text(app.name).font(.system(size: 23, weight: .semibold, design: .rounded))
                            Text(app.size + " · " + app.source).foregroundStyle(Palette.coral)
                            Text(app.path).font(.system(size: 11, design: .monospaced)).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                            Text(app.bundleID).font(.system(size: 11)).foregroundStyle(Palette.muted).textSelection(.enabled)
                            Button(store.t("在 Finder 顯示", "Show in Finder")) { store.reveal(URL(fileURLWithPath: app.path)) }
                                .buttonStyle(PawButtonStyle(prominent: false))
                            Spacer()
                            Text(store.t("以這個 App 的精確路徑檢查相關檔案；保護仍在使用中的共用資料。", "Review related files for this exact app path, preserving shared data still in use."))
                                .font(.system(size: 11)).foregroundStyle(Palette.muted)
                            Button(store.t("檢查移除項目", "Review uninstall")) { store.uninstall.review(app) }
                                .buttonStyle(PawButtonStyle()).disabled(store.busy)
                        }.padding(20).frame(minWidth: 250, maxWidth: 310).background(Palette.card)
                    } else {
                        VStack(spacing: 18) {
                            CatMark().frame(width: 65, height: 65)
                            Text(store.t("揀一個 App，先看看。", "Pick an app for a closer look."))
                            Text(store.t("受保護的系統 App 不會列入移除清單。", "Protected system apps are excluded from the uninstall list."))
                                .font(.system(size: 11)).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
                        }.frame(minWidth: 250, maxWidth: 310, maxHeight: .infinity).padding(20)
                    }
                }.pawCard()
            }
            Text(store.t("\(mole.visibleApps.count) 個 App · 清單由 Mole 引擎提供", "\(mole.visibleApps.count) apps · Inventory from the Mole engine"))
                .font(.system(size: 10)).foregroundStyle(Palette.muted)
        }.padding(28).task { if mole.apps.isEmpty { mole.refreshApps() } }
            .sheet(isPresented: Binding(get: { store.uninstall.visible }, set: { store.uninstall.visible = $0 })) { uninstallSheet }
    }
    private var uninstallSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(store.uninstall.app?.name ?? store.t("應用程式", "Application")).font(.system(size: 25, weight: .semibold, design: .rounded))
            Text(EngineAction.uninstall.impact(zh: store.language == "zh")).font(.system(size: 12)).foregroundStyle(Palette.muted)
            if store.uninstall.loading { HStack { ProgressView(); Text(store.t("正在檢查相關檔案及共用資料…", "Checking related files and shared data…")) }.frame(maxWidth: .infinity, minHeight: 120) }
            if let error = store.uninstall.error { InlineError(text: error) }
            if let report = store.uninstall.report {
                if report.shared { Label(store.t("找到其他副本，共用資料會保留。", "Another copy uses shared data; that data will be kept."), systemImage: "shield").foregroundStyle(Palette.sage) }
                if report.sensitive { Text(store.t("包含可能有個人設定或資料的路徑，請先細看。", "Some paths may contain personal settings or data. Review them carefully.")).foregroundStyle(Palette.coral) }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(report.files.enumerated()), id: \.offset) { _, file in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: file.kind == "review" ? "eye" : file.kind == "app" ? "app" : "doc").foregroundStyle(Palette.sage)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(file.path).font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                                    if file.kind == "review" { Text(store.t("只供檢視，不會自動移除", "Review only; no automatic removal")).font(.system(size: 10)).foregroundStyle(Palette.coral) }
                                    if file.kind == "system" { Text(store.t("可能需要管理員授權", "May require administrator access")).font(.system(size: 10)).foregroundStyle(Palette.muted) }
                                }
                            }; Divider()
                        }
                    }
                }.frame(maxHeight: 380)
            }
            HStack {
                if store.uninstall.loading { Button(store.t("停止", "Stop")) { store.uninstall.cancel() } }
                else { Button(store.t("返回", "Back")) { store.uninstall.visible = false }.keyboardShortcut(.cancelAction) }
                Spacer()
                Button(store.t("前往移除確認…", "Continue to uninstall…")) { store.openReviewedUninstall() }.buttonStyle(PawButtonStyle()).disabled(store.busy || store.uninstall.report == nil)
            }
        }.padding(28).frame(width: 720).background(Palette.background).interactiveDismissDisabled(store.uninstall.loading)
    }
}

struct InlineError: View {
    let text: String
    var body: some View {
        Label(text, systemImage: "exclamationmark.circle").font(.system(size: 11)).textSelection(.enabled)
            .foregroundStyle(Palette.coral).padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Palette.peach, in: RoundedRectangle(cornerRadius: 6))
    }
}
