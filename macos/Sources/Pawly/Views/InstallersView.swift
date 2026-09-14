import SwiftUI
import PawlyCore

struct InstallersView: View {
    @Bindable var store: AppStore
    @Bindable var files: InstallerStore
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeading(title: store.t("安裝檔", "Installers"), subtitle: store.t("完整引擎的安裝檔搜尋，逐項選擇並移到垃圾桶。", "The engine's full installer search, with individual selection and moves to Trash."))
            HStack {
                TextField(store.t("搜尋安裝檔或路徑", "Search installers or paths"), text: $files.search).textFieldStyle(.roundedBorder)
                Picker("", selection: $files.source) {
                    Text(store.t("全部來源", "All sources")).tag("all")
                    ForEach(files.sources, id: \.self) { Text($0).tag($0) }
                }.frame(width: 160)
                Button(store.t(files.scanning ? "停止" : "重新掃描", files.scanning ? "Stop" : "Refresh")) {
                    if files.scanning { files.cancel() } else { files.scan() }
                }.buttonStyle(PawButtonStyle(prominent: false)).disabled(files.reviewing || files.cleaning || store.mole.operationActive)
            }
            if let error = files.inventory?.error { InlineError(text: error) }
            if let outcome = files.outcome { Text(outcome).font(.system(size: 12)).foregroundStyle(files.hasFailures ? Palette.coral : Palette.sage).textSelection(.enabled) }
            if files.scanning {
                VStack(spacing: 20) {
                    ProgressView()
                    Text(store.t("正在搜尋下載項目、桌面及其他支援位置…", "Searching Downloads, Desktop and other supported locations…"))
                    Text("DMG · PKG · MPKG · ISO · XIP · ZIP").font(.system(size: 11))
                }.foregroundStyle(Palette.muted).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack {
                    Text(store.t("\(files.visible.count) 個安裝檔", "\(files.visible.count) installers")).foregroundStyle(Palette.muted)
                    Spacer()
                    Button(store.t("全選此頁結果", "Select filtered results")) { files.selected.formUnion(files.visible.map(\.id)) }
                    Button(store.t("取消選取", "Clear selection")) { files.selected.removeAll() }
                }.font(.system(size: 11)).disabled(files.busy)
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(files.visible) { file in
                            HStack(spacing: 14) {
                                Toggle("", isOn: Binding(get: { files.selected.contains(file.id) }, set: { if $0 { files.selected.insert(file.id) } else { files.selected.remove(file.id) } }))
                                    .toggleStyle(.checkbox).labelsHidden().accessibilityLabel(file.name)
                                Image(systemName: "shippingbox").font(.system(size: 23)).foregroundStyle(Palette.sage)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(file.name).fontWeight(.medium).lineLimit(1)
                                    Text(file.url.path).font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted).lineLimit(1).truncationMode(.middle)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 6) {
                                    Text(FileSize.string(file.bytes)).font(.system(size: 12, weight: .semibold, design: .rounded))
                                    Text(file.source).font(.system(size: 10)).foregroundStyle(Palette.muted)
                                }
                                Button { store.reveal(file.url) } label: { Image(systemName: "arrow.up.right.square") }.buttonStyle(.plain).help(store.t("在 Finder 顯示", "Show in Finder"))
                            }.padding(17)
                            Divider()
                        }
                        if files.visible.isEmpty {
                            VStack(spacing: 18) {
                                CatMark().frame(width: 70, height: 70)
                                Text(store.t("這次沒有符合條件的安裝檔。", "No matching installers this time."))
                            }.padding(55).frame(maxWidth: .infinity)
                        }
                    }
                }.pawCard()
                if let count = files.inventory?.excluded, count > 0 {
                    Text(store.t("\(count) 個項目因檔案已變更或路徑不適用而略過。", "\(count) items skipped because their files changed or paths were unsuitable.")).font(.system(size: 11)).foregroundStyle(Palette.muted)
                }
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(store.t("已選 \(files.picked.count) 個 · \(FileSize.string(files.pickedBytes))", "\(files.picked.count) selected · \(FileSize.string(files.pickedBytes))")).fontWeight(.semibold)
                        Text(store.t("先檢查檔案是否仍然相同及未被使用，再確認移到垃圾桶。", "Check that files are unchanged and unused before confirming moves to Trash.")).font(.system(size: 10)).foregroundStyle(Palette.muted)
                    }
                    Spacer()
                    Button(store.t("檢查所選項目", "Review selection")) { files.review() }.buttonStyle(PawButtonStyle()).disabled(files.picked.isEmpty || files.busy || store.mole.operationActive)
                }
            }
        }.padding(28).task { if files.inventory == nil { files.scan() } }
            .sheet(isPresented: $files.reviewVisible) { reviewSheet }
    }
    private var reviewSheet: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label(store.t("最後看看，安心整理。", "One last look before tidying."), systemImage: "pawprint.fill").font(.system(size: 23, weight: .semibold, design: .rounded))
            Text(store.t("只會移動通過檢查的所選安裝檔。你可以在 Finder 垃圾桶使用「放回原處」還原。", "Only selected installers that pass checks will move. Use Put Back in Finder's Trash to restore them.")).font(.system(size: 12)).foregroundStyle(Palette.muted)
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    ForEach(files.plan) { file in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: files.results[file.id]?.success == true ? "checkmark.circle.fill" : files.results[file.id] == nil ? "clock" : "exclamationmark.circle").foregroundStyle(files.results[file.id]?.success == true ? Palette.sage : Palette.coral)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(file.name).fontWeight(.medium)
                                Text(file.url.path).font(.system(size: 10, design: .monospaced)).textSelection(.enabled)
                                if let detail = files.results[file.id]?.detail, !detail.isEmpty { Text(detail).font(.system(size: 11)).foregroundStyle(Palette.coral) }
                            }
                            Spacer(); Text(FileSize.string(file.bytes))
                        }
                        Divider()
                    }
                }
            }.frame(maxHeight: 340)
            if files.reviewing || files.cleaning { HStack { ProgressView().controlSize(.small); Text(files.current).font(.system(size: 11)).lineLimit(1) } }
            HStack {
                if files.reviewing || files.cleaning {
                    Button(store.t("停止", "Stop")) { files.cancel() }
                } else {
                    Button(store.t("返回", "Back")) { files.reviewVisible = false }.keyboardShortcut(.cancelAction)
                }
                Spacer()
                Button(store.t("移到垃圾桶 · \(files.ready.count)", "Move to Trash · \(files.ready.count)")) {
                    files.moveConfirmed { moved, bytes, failures in store.record(moved: moved, bytes: bytes, failures: failures) }
                }.buttonStyle(PawButtonStyle()).disabled(files.busy || files.ready.isEmpty)
            }
        }.padding(28).frame(width: 690).background(Palette.background).interactiveDismissDisabled(files.busy)
    }
}
