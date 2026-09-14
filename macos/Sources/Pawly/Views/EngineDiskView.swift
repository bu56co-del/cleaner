import SwiftUI
import PawlyCore

struct EngineDiskView: View {
    @Bindable var store: AppStore
    @Bindable var mole: MoleStore
    @State private var largeFiles = false
    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            PageHeading(title: store.t("空間探索", "Disk explorer"),
                        subtitle: store.t("逐層探索磁碟，找出大型檔案。雙擊資料夾繼續探索。", "Explore your disk and find large files. Double-click a folder to look inside."))
            HStack {
                Button { mole.goBack() } label: { Image(systemName: "chevron.left") }.disabled(mole.diskBackStack.isEmpty || mole.loadingDisk)
                Button(store.t("總覽", "Overview")) { mole.explore(nil) }.disabled(mole.loadingDisk)
                Button(store.t("個人資料夾", "Home")) { mole.explore(FileManager.default.homeDirectoryForCurrentUser.path) }.disabled(mole.loadingDisk)
                Button(store.t("選擇資料夾", "Choose folder")) { mole.chooseDiskFolder() }.disabled(mole.loadingDisk)
                Spacer()
                if mole.loadingDisk {
                    Button(store.t("停止", "Stop")) { mole.cancelDisk() }
                } else {
                    Button { mole.explore(mole.diskLocation, remember: false) } label: { Image(systemName: "arrow.clockwise") }
                }
            }.buttonStyle(.bordered)
            Text(mole.diskLocation ?? store.t("這部 Mac · 常用位置", "This Mac · Common locations"))
                .font(.system(size: 11, design: .monospaced)).foregroundStyle(Palette.muted).textSelection(.enabled).lineLimit(2)
            if let error = mole.diskError { InlineError(text: error) }
            if mole.loadingDisk {
                VStack(spacing: 18) { ProgressView(); Text(store.t("正在量度檔案及資料夾…", "Measuring files and folders…")) }
                    .foregroundStyle(Palette.muted).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let report = mole.disk {
                HStack(spacing: 16) {
                    stat(store.t("本次量度", "Measured"), FileSize.string(report.totalSize))
                    stat(store.t("項目", "Items"), String(report.entries.count))
                    if let count = report.totalFiles { stat(store.t("檔案", "Files"), String(count)) }
                    Spacer()
                    if report.overview { Text(store.t("各位置可能互相包含，總和不代表磁碟已用空間。", "Locations may overlap; their sum is not disk usage.")).font(.system(size: 10)).foregroundStyle(Palette.muted).frame(maxWidth: 240) }
                }.padding(18).pawCard()
                HStack {
                    TextField(store.t("搜尋此層檔案", "Filter this folder"), text: $mole.diskSearch).textFieldStyle(.roundedBorder)
                    Picker("", selection: $mole.diskSort) {
                        Text(store.t("按大小", "Size")).tag("size"); Text(store.t("按名稱", "Name")).tag("name")
                    }.frame(width: 125)
                    Toggle(store.t("大型檔案", "Large files"), isOn: $largeFiles).toggleStyle(.button).disabled((report.largeFiles ?? []).isEmpty)
                }
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if largeFiles {
                            ForEach((report.largeFiles ?? []).filter { mole.diskSearch.isEmpty || $0.name.localizedCaseInsensitiveContains(mole.diskSearch) }) { file in
                                row(file.name, path: file.path, bytes: file.size, directory: false)
                            }
                        } else {
                            ForEach(mole.visibleDiskEntries) { entry in
                                row(entry.name, path: entry.path, bytes: entry.size, directory: entry.isDirectory)
                            }
                        }
                    }
                }.pawCard()
                HStack {
                    Text(store.t("瀏覽只會讀取資料。", "Browsing is read-only.")).font(.system(size: 11)).foregroundStyle(Palette.muted)
                    Spacer()
                    Button(store.t("多選與移到垃圾桶…", "Select files & move to Trash…")) { store.openOperation(.analyze, target: mole.diskLocation) }
                        .buttonStyle(PawButtonStyle(prominent: false)).disabled(store.busy)
                }
            } else {
                VStack(spacing: 20) { CatMark().frame(width: 70, height: 70); Text(store.t("選擇位置，開始探索。", "Choose a location to explore.")) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }.padding(28).onChange(of: mole.diskLocation) { _, _ in largeFiles = false }.task { if mole.disk == nil && !mole.loadingDisk { mole.explore(nil, remember: false) } }
    }
    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) { Text(title).font(.system(size: 10)).foregroundStyle(Palette.muted); Text(value).font(.system(size: 23, weight: .semibold, design: .rounded)) }
    }
    private func row(_ name: String, path: String, bytes: Int64, directory: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: directory ? "folder.fill" : "doc").foregroundStyle(directory ? Palette.sage : Palette.lavender).frame(width: 23)
            VStack(alignment: .leading, spacing: 7) {
                Text(name).fontWeight(.medium).lineLimit(1)

            }
            Text(FileSize.string(bytes)).font(.system(size: 12, weight: .medium, design: .monospaced)).frame(width: 95, alignment: .trailing)
            if directory {
                Button { mole.explore(path) } label: { Image(systemName: "chevron.right") }.buttonStyle(.plain).help(store.t("打開資料夾", "Open folder"))
            }
            Button { store.reveal(URL(fileURLWithPath: path)) } label: { Image(systemName: "arrow.up.right.square") }.buttonStyle(.plain).help(store.t("在 Finder 顯示", "Show in Finder"))
        }.padding(.horizontal, 16).padding(.vertical, 11).contentShape(Rectangle()).onTapGesture(count: 2) { if directory { mole.explore(path) } }
            .contextMenu {
                if directory { Button(store.t("打開資料夾", "Open folder")) { mole.explore(path) } }
                Button(store.t("在 Finder 顯示", "Show in Finder")) { store.reveal(URL(fileURLWithPath: path)) }
                Button(store.t("複製路徑", "Copy path")) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(path, forType: .string) }
            }
    }
}
