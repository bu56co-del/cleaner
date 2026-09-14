import SwiftUI
import PawlyCore

struct ReviewSheet: View {
    @Bindable var store: AppStore
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 13) {
                CatMark().frame(width: 43, height: 43)
                VStack(alignment: .leading, spacing: 5) {
                    Text(store.t("最後看一眼。", "One last look.")).font(.system(size: 24, weight: .bold, design: .rounded))
                    Text(store.t("只處理以下通過檢查的項目。", "Only the listed items that pass review will be moved."))
                        .font(.system(size: 12)).foregroundStyle(Palette.muted)
                }
            }
            Label(store.t("檔案會移到垃圾桶，不會永久刪除。", "Files go to Trash, with no permanent-delete fallback."), systemImage: "trash")
                .font(.system(size: 12)).foregroundStyle(Palette.sage).padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.sageTint, in: RoundedRectangle(cornerRadius: 6))
            ScrollView {
                LazyVStack(spacing: 13) {
                    ForEach(store.reviewItems) { item in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: statusIcon(item)).foregroundStyle(store.reviewResults[item.id]?.success == true ? Palette.sage : Palette.muted)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name).fontWeight(.medium)
                                Text(item.url.path).font(.system(size: 10)).foregroundStyle(Palette.muted).textSelection(.enabled)
                                if let result = store.reviewResults[item.id], !result.success {
                                    Text(result.detail).font(.system(size: 10)).foregroundStyle(Palette.coral)
                                } else if store.reviewResults[item.id] == nil {
                                    Text(store.t("未完成檢查；不會處理", "Not yet checked; will not be moved")).font(.system(size: 10)).foregroundStyle(Palette.muted)
                                }
                            }
                            Spacer()
                            Text(FileSize.string(item.bytes)).font(.system(size: 11, weight: .medium)).monospacedDigit()
                        }
                    }
                }.padding(2)
            }.frame(minHeight: 150, maxHeight: 310)
            if store.reviewing || store.cleaning {
                HStack {
                    ProgressView().controlSize(.small)
                    Text(store.operationStatus).font(.system(size: 11)).lineLimit(1)
                    Spacer()
                    Button(store.t("完成目前項目後停止", "Stop after current item")) { store.cancelReview() }.font(.system(size: 10))
                }
            }
            Text(store.t("移到垃圾桶不代表即時釋放空間；只有日後清空垃圾桶才會永久刪除。快取重建可能需要重新下載資料。", "Moving to Trash does not immediately reclaim disk space. Emptying Trash later permanently removes files. Apps may need to download caches again."))
                .font(.system(size: 11)).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
            Divider()
            HStack {
                Button(store.t("返回", "Go back")) { store.reviewVisible = false }.buttonStyle(PawButtonStyle(prominent: false))
                    .disabled(store.reviewing || store.cleaning).keyboardShortcut(.cancelAction)
                Spacer()
                Text(FileSize.string(store.readyBytes)).font(.system(size: 17, weight: .semibold, design: .rounded))
                Button(store.t("移到垃圾桶 · \(store.readyItems.count)", "Move to Trash · \(store.readyItems.count)")) { store.cleanConfirmed() }
                    .buttonStyle(PawButtonStyle()).disabled(store.reviewing || store.cleaning || store.readyItems.isEmpty)
                    .accessibilityIdentifier("confirm-trash")
            }
        }.padding(28).frame(width: 620).background(Palette.background).foregroundStyle(Palette.ink)
            .interactiveDismissDisabled(store.reviewing || store.cleaning)
    }
    private func statusIcon(_ item: CleanupItem) -> String {
        guard let result = store.reviewResults[item.id] else { return "clock" }
        return result.success ? "checkmark.circle.fill" : "shield.lefthalf.filled"
    }
}
