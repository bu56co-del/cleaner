import SwiftUI
import PawlyCore

struct DiskExplorerView: View {
    @Bindable var store: AppStore
    var body: some View {
        VStack(alignment: .leading, spacing: 23) {
            PageHeading(title: store.t("空間都躲在哪裡？", "Where does it all go?"),
                        subtitle: store.t("選一個資料夾，看看誰佔了最多空間。這裡只會讀取檔案。", "Pick a folder and see what takes up space. Exploration is read-only."))
            HStack {
                IconTile(icon: "internaldrive", color: Palette.sage, tint: Palette.sageTint)
                VStack(alignment: .leading, spacing: 6) {
                    Text(store.t("這部 Mac", "This Mac")).fontWeight(.semibold)
                    Text(store.diskAvailable ? store.t("\(FileSize.string(store.diskFree)) 可用，共 \(FileSize.string(store.diskTotal))", "\(FileSize.string(store.diskFree)) available of \(FileSize.string(store.diskTotal))") : store.t("無法讀取磁碟資訊", "Disk information unavailable"))
                        .font(.system(size: 11)).foregroundStyle(Palette.muted)
                }
                Spacer()
                if store.diskAvailable {
                    Gauge(value: Double(store.diskTotal - store.diskFree), in: 0...Double(max(store.diskTotal, 1))) { EmptyView() }
                        .gaugeStyle(.accessoryCircularCapacity).tint(Palette.sage).labelsHidden()
                }
            }.padding(20).pawCard()
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(store.folder?.lastPathComponent ?? store.t("選擇一個小角落", "Choose a little corner")).font(.system(size: 16, weight: .semibold, design: .rounded))
                    Text(store.folder?.path ?? store.t("例如「下載項目」或你的專案資料夾", "Try Downloads or a project folder"))
                        .font(.system(size: 11)).foregroundStyle(Palette.muted).lineLimit(1).truncationMode(.middle)
                }
                Spacer()
                if store.inspecting {
                    Button(store.t("停止", "Stop")) { store.cancelInspection() }.buttonStyle(PawButtonStyle(prominent: false))
                } else {
                    Button { store.chooseFolder() } label: { Label(store.t("選擇資料夾", "Choose folder"), systemImage: "folder.badge.plus") }
                        .buttonStyle(PawButtonStyle()).accessibilityIdentifier("choose-folder")
                }
            }
            if store.inspecting {
                VStack(spacing: 16) {
                    ProgressView()
                    Text(store.t("正在量度這個資料夾…", "Measuring this folder…")).foregroundStyle(Palette.muted)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let report = store.diskReport {
                if !report.completed || !report.warnings.isEmpty {
                    Label(store.t("部分結果：有項目未能完整量度。", "Partial results: some items could not be measured."), systemImage: "info.circle")
                        .font(.system(size: 11)).foregroundStyle(Palette.coral)
                }
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(report.entries) { entry in
                            HStack(spacing: 15) {
                                Image(systemName: entry.isDirectory ? "folder.fill" : "doc").foregroundStyle(entry.isDirectory ? Palette.sage : Palette.lavender).frame(width: 22)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(entry.url.lastPathComponent).font(.system(size: 12, weight: .medium)).lineLimit(1)
                                    GeometryReader { geometry in
                                        RoundedRectangle(cornerRadius: 2).fill(Palette.sageTint)
                                        RoundedRectangle(cornerRadius: 2).fill(Palette.sage.opacity(0.65))
                                            .frame(width: max(2, geometry.size.width * Double(entry.bytes) / Double(max(report.entries.first?.bytes ?? 1, 1))))
                                    }.frame(height: 5)
                                }
                                Text(FileSize.string(entry.bytes)).font(.system(size: 12, weight: .medium, design: .rounded)).frame(width: 85, alignment: .trailing)
                                Button { store.reveal(entry.url) } label: { Image(systemName: "arrow.up.right.square") }
                                    .buttonStyle(.plain).help(store.t("在 Finder 顯示", "Show in Finder"))
                            }.padding(17)
                            Divider()
                        }
                    }
                    if report.entries.isEmpty { Text(store.t("沒有可顯示的檔案。", "No measured files to show.")).padding(30).foregroundStyle(Palette.muted) }
                }.pawCard()
            } else {
                VStack(spacing: 18) {
                    Image(systemName: "folder.badge.questionmark").font(.system(size: 47, weight: .ultraLight)).foregroundStyle(Palette.sage)
                    Text(store.t("好奇，是整理的第一步。", "A little curiosity goes a long way."))
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                    Text(store.t("檔案大小會逐項量度，不會更改你的資料。", "See measured file sizes without changing your files."))
                        .font(.system(size: 12)).foregroundStyle(Palette.muted)
                }.frame(maxWidth: .infinity, maxHeight: .infinity).pawCard()
            }
        }.padding(.horizontal, 32).padding(.top, 14).padding(.bottom, 18)
    }
}
