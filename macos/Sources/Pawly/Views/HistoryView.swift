import SwiftUI
import PawlyCore

struct HistoryView: View {
    @Bindable var store: AppStore
    var body: some View {
        VStack(alignment: .leading, spacing: 23) {
            HStack(alignment: .top) {
                PageHeading(title: store.t("每次整理，都有跡可尋。", "Your little wins."),
                            subtitle: store.t("這裡記錄 Pawly 的操作。移到垃圾桶的檔案可由 Finder 還原。", "Your Pawly activity, saved locally. Restore trashed files with Finder."))
                Spacer()
                Button(store.t("開啟垃圾桶", "Open Trash")) { store.openTrash() }.buttonStyle(PawButtonStyle(prominent: false))
            }
            if store.history.isEmpty {
                VStack(spacing: 13) {
                    Mascot().frame(width: 200, height: 200).clipShape(RoundedRectangle(cornerRadius: 6))
                    Text(store.t("整理日記，等你寫第一頁。", "A fresh page for a fresh start."))
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                    Text(store.t("完成第一次清理後，紀錄就會出現在這裡。", "Your first cleanup will appear here when it's done."))
                        .font(.system(size: 12)).foregroundStyle(Palette.muted)
                    Button(store.t("回去整理", "Let's tidy up")) { store.page = .cleanup }.buttonStyle(PawButtonStyle()).padding(.top, 8)
                }.frame(maxWidth: .infinity, maxHeight: .infinity).pawCard()
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(store.history) { event in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    IconTile(icon: event.failed.isEmpty ? "checkmark" : "exclamationmark", color: Palette.sage, tint: Palette.sageTint)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(store.t("\(event.moved.count) 個項目已移到垃圾桶", "\(event.moved.count) items moved to Trash")).fontWeight(.semibold)
                                        Text(event.date.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 11)).foregroundStyle(Palette.muted)
                                    }
                                    Spacer()
                                    Text(FileSize.string(event.bytes)).font(.system(size: 20, weight: .semibold, design: .rounded)).foregroundStyle(Palette.sage)
                                }
                                DisclosureGroup(store.t("檢視項目及結果", "View items and results")) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        ForEach(event.moved, id: \.self) { Text($0).font(.system(size: 10)).textSelection(.enabled) }
                                        ForEach(event.failed, id: \.self) { Text($0).font(.system(size: 10)).foregroundStyle(Palette.coral).textSelection(.enabled) }
                                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 6)
                                }.font(.system(size: 11)).foregroundStyle(Palette.muted)
                            }.padding(19).pawCard()
                        }
                    }
                }
            }
        }.padding(.horizontal, 32).padding(.top, 14).padding(.bottom, 18)
    }
}
