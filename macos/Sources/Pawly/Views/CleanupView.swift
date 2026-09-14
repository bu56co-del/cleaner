import SwiftUI
import PawlyCore

struct CleanupView: View {
    @Bindable var store: AppStore
    var filtered: [CleanupItem] {
        (store.report?.items ?? []).filter {
            (store.category == nil || $0.category == store.category) &&
            (store.search.isEmpty || $0.name.localizedCaseInsensitiveContains(store.search))
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                PageHeading(title: store.t("每個檔案，由你作主。", "Keep what matters."),
                            subtitle: store.t("選擇候選項目，再檢查及確認。未勾選的檔案會保留。", "Pick the items to review. Unselected files stay exactly where they are."))
                Spacer()
                Button(store.scanning ? store.t("停止", "Stop") : store.t("重新掃描", "Scan Mac")) {
                    if store.scanning { store.cancelScan() } else { store.scan() }
                }.buttonStyle(PawButtonStyle(prominent: false)).disabled(store.reviewing || store.cleaning)
            }
            HStack(spacing: 6) {
                filterPill(nil, store.t("全部", "All"))
                ForEach(CleanupCategory.allCases) { filterPill($0, store.title($0)) }
                Spacer(minLength: 2)
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Palette.muted)
                    TextField(store.t("搜尋檔案", "Search files"), text: $store.search).textFieldStyle(.plain)
                }.font(.system(size: 11)).padding(9).frame(width: 145).pawCard()
            }
            if store.scanning {
                empty(icon: "pawprint", title: store.t("小貓正在巡邏…", "Looking around…"), detail: store.scanPath)
                    .overlay(alignment: .bottom) { ProgressView().padding(.bottom, 30) }
            } else if store.report == nil {
                empty(icon: "sparkles", title: store.t("先掃描，再慢慢揀。", "First, a little look around."),
                      detail: store.t("按「重新掃描」，開始檢視這部 Mac。", "Choose Scan Mac to discover review candidates."))
            } else if filtered.isEmpty {
                empty(icon: "checkmark.seal", title: store.t("這裡沒有候選項目。", "Nothing to review here."),
                      detail: store.t("試試其他分類，或重新掃描。", "Try another category or run a fresh scan."))
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Text(store.t("項目及位置", "ITEM & LOCATION"))
                        Spacer()
                        Text(store.t("大小", "SIZE"))
                    }.font(.system(size: 9, weight: .semibold)).tracking(1.3).foregroundStyle(Palette.muted)
                        .padding(.horizontal, 20).padding(.vertical, 13)
                    Divider()
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filtered) { item in
                                fileRow(item)
                                Divider().padding(.leading, 50)
                            }
                        }
                    }
                }.pawCard()
            }
            if let report = store.report, !report.warnings.isEmpty {
                DisclosureGroup(store.t("\(report.warnings.count) 個掃描提示", "\(report.warnings.count) scan notes")) {
                    ScrollView { Text(report.warnings.joined(separator: "\n")).font(.system(size: 10)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(maxHeight: 65)
                }.font(.system(size: 11)).foregroundStyle(Palette.muted)
            }
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(store.t("已選 \(store.selected.count) 個項目", "\(store.selected.count) items selected")).font(.system(size: 12, weight: .semibold))
                    Text(store.t("移到垃圾桶後，可在 Finder 還原。", "Moved items can be restored from Trash in Finder."))
                        .font(.system(size: 10)).foregroundStyle(Palette.muted)
                }
                if !store.selected.isEmpty {
                    Button(store.t("取消選取", "Deselect")) { store.selected.removeAll() }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Palette.coral)
                }
                Spacer()
                Text(FileSize.string(store.selectedBytes)).font(.system(size: 21, weight: .semibold, design: .rounded))
                Button { store.startReview() } label: {
                    Label(store.t("檢查所選項目", "Review selected"), systemImage: "arrow.right")
                }.buttonStyle(PawButtonStyle()).disabled(store.selected.isEmpty || store.busy).accessibilityIdentifier("review-selected")
            }.padding(.top, 5)
        }.padding(.horizontal, 32).padding(.top, 14).padding(.bottom, 18)
    }
    private func filterPill(_ category: CleanupCategory?, _ text: String) -> some View {
        Button { store.category = category } label: {
            Text(text).font(.system(size: 11, weight: .medium)).padding(.horizontal, 12).padding(.vertical, 8)
                .foregroundStyle(store.category == category ? Palette.coral : Palette.muted)
                .background(store.category == category ? Palette.peach : .clear, in: RoundedRectangle(cornerRadius: 4))
        }.buttonStyle(.plain)
    }
    private func fileRow(_ item: CleanupItem) -> some View {
        HStack(spacing: 12) {
            Toggle(item.name, isOn: Binding(get: { store.selected.contains(item.id) }, set: { _ in store.toggle(item) }))
                .labelsHidden().toggleStyle(.checkbox)
            Image(systemName: item.category.icon).font(.system(size: 19)).foregroundStyle(item.category.color).frame(width: 24)
            VStack(alignment: .leading, spacing: 5) {
                Text(item.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                Text(item.url.path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                    .font(.system(size: 10)).foregroundStyle(Palette.muted).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Text(FileSize.string(item.bytes)).font(.system(size: 12, weight: .medium, design: .rounded)).monospacedDigit()
            Button { store.reveal(item.url) } label: { Image(systemName: "folder") }
                .buttonStyle(.plain).foregroundStyle(Palette.muted).help(store.t("在 Finder 顯示", "Show in Finder"))
        }.padding(.horizontal, 18).padding(.vertical, 14).contextMenu {
            Button(store.t("在 Finder 顯示", "Show in Finder")) { store.reveal(item.url) }
            Button(store.t("複製路徑", "Copy path")) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(item.id, forType: .string) }
        }
    }
    private func empty(icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 15) {
            Image(systemName: icon).font(.system(size: 38, weight: .light)).foregroundStyle(Palette.coral)
            Text(title).font(.system(size: 21, weight: .semibold, design: .rounded))
            Text(detail).font(.system(size: 12)).foregroundStyle(Palette.muted)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).pawCard()
    }
}
