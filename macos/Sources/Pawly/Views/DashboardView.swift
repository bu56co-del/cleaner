import SwiftUI
import PawlyCore

struct DashboardView: View {
    @Bindable var store: AppStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 23) {
                PageHeading(title: store.t("總覽", "Overview"),
                            subtitle: store.t("掃描、檢視，再決定要清理甚麼。", "Scan, review and choose what to clean."))
                hero
                HStack(spacing: 13) {
                    stat(icon: "internaldrive", title: store.t("目前可用空間", "Available space"),
                         value: store.diskAvailable ? FileSize.string(store.diskFree) : "—", color: Palette.sage)
                    stat(icon: "square.grid.2x2", title: store.t("可檢視的項目", "Items to review"),
                         value: store.report.map { "\($0.items.count)" } ?? "—", color: Palette.coral)
                    stat(icon: "checkmark.shield", title: store.t("快速整理方式", "Quick cleanup method"),
                         value: store.t("移到垃圾桶", "Move to Trash"), color: Palette.lavender)
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach([Page.deepClean, .applications, .projects, .installers, .maintenance, .disk], id: \.self) { page in
                        Button { store.page = page } label: {
                            HStack(spacing: 11) {
                                Image(systemName: page.icon).font(.system(size: 20)).foregroundStyle(Palette.sage).frame(width: 28)
                                Text(store.title(page)).font(.system(size: 12, weight: .semibold))
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 9)).foregroundStyle(Palette.muted)
                            }.padding(16).frame(maxWidth: .infinity).pawCard().contentShape(Rectangle())
                        }.buttonStyle(.plain).disabled(store.busy)
                    }
                }
                HStack {
                    Text(store.t("從這些小地方開始", "A little tidying goes a long way")).font(.system(size: 16, weight: .semibold, design: .rounded))
                    Spacer()
                    if store.report != nil {
                        Button(store.t("檢視全部", "View all") + "  →") { store.category = nil; store.page = .cleanup }
                            .buttonStyle(.plain).foregroundStyle(Palette.coral).font(.system(size: 12, weight: .medium))
                    }
                }
                VStack(spacing: 0) {
                    ForEach(CleanupCategory.allCases) { category in
                        CategoryRow(store: store, category: category)
                        if category != .installers { Divider().overlay(Palette.border).padding(.leading, 76) }
                    }
                }.pawCard()
                if let report = store.report, !report.completed || !report.warnings.isEmpty {
                    Label(store.t("部分位置未能完整掃描，未量度的項目不會列入清理。", "Some locations could not be fully scanned. Unmeasured items are excluded."),
                          systemImage: "info.circle").font(.system(size: 11)).foregroundStyle(Palette.muted)
                }
            }.padding(.horizontal, 32).padding(.top, 28).padding(.bottom, 18)
        }
    }
    private var hero: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Label(store.scanning ? store.t("小貓巡邏中", "A LITTLE LOOK AROUND") : store.t("你的整理小幫手", "YOUR TIDYING COMPANION"),
                      systemImage: "sparkle")
                    .font(.system(size: 9, weight: .semibold)).tracking(1.1).foregroundStyle(Palette.coral)
                Text(heroTitle).font(.system(size: 27, weight: .bold, design: .rounded)).fixedSize(horizontal: false, vertical: true)
                Text(heroSubtitle).font(.system(size: 12)).lineSpacing(4).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    if store.scanning {
                        ProgressView().controlSize(.small)
                        Button(store.t("停止掃描", "Stop scan")) { store.cancelScan() }.buttonStyle(PawButtonStyle(prominent: false))
                    } else {
                        Button {
                            if store.report == nil { store.scan() } else { store.page = .cleanup }
                        } label: {
                            Label(store.report == nil ? store.t("開始掃描", "Let's tidy up") : store.t("檢視掃描結果", "Review my files"),
                                  systemImage: store.report == nil ? "pawprint.fill" : "arrow.right")
                        }.buttonStyle(PawButtonStyle()).accessibilityIdentifier("primary-scan")
                        if store.report != nil {
                            Button { store.scan() } label: { Image(systemName: "arrow.clockwise") }
                                .buttonStyle(.plain).help(store.t("重新掃描", "Scan again"))
                        }
                    }
                }.padding(.top, 3)
                Text(store.scanning ? store.scanPath : store.t("只掃描，不會自動刪除任何檔案", "A scan only. No files are changed."))
                    .font(.system(size: 10)).foregroundStyle(Palette.muted).lineLimit(1)
            }.padding(.leading, 27).padding(.vertical, 24).frame(maxWidth: .infinity, alignment: .leading)
            Mascot().frame(width: 160, height: 160).blendMode(.multiply).padding(.trailing, 16)
        }
        .background(Palette.adaptive(0xFBF4EC, 0xE8D8C5), in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.border, lineWidth: 1))
        .environment(\.colorScheme, .light)
    }
    private var heroTitle: String {
        if store.scanning { return store.t("讓我四處看看…", "Let me sniff around…") }
        if let report = store.report {
            return report.items.isEmpty ? store.t("這次沒有找到候選項目。", "Looking lovely in here.") :
                store.t("找到 \(FileSize.string(report.bytes))，\n一起看看？", "\(FileSize.string(report.bytes)) to review.\nShall we take a look?")
        }
        return store.t("準備好，輕輕鬆鬆\n整理一下？", "A fresh start,\none paw at a time.")
    }
    private var heroSubtitle: String {
        if store.scanning { return store.t("正在量度檔案大小。你可以隨時停止。", "Measuring files on your Mac. Stop whenever you like.") }
        if store.report != nil { return store.t("這是候選檔案的大小；由你揀選要保留或清理的項目。", "These are review candidates. Choose what stays and what goes.") }
        return store.t("找出快取、舊記錄及安裝檔。\n先看清楚，再由你決定。", "Find app caches, old logs, and installers.\nAlways reviewed. Always your choice.")
    }
    private func stat(icon: String, title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon).font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.muted)
            Text(value).font(.system(size: 21, weight: .semibold, design: .rounded)).foregroundStyle(color)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(17).pawCard()
    }
}

struct CategoryRow: View {
    let store: AppStore
    let category: CleanupCategory
    var body: some View {
        Button { store.category = category; store.page = .cleanup } label: {
            HStack(spacing: 14) {
                IconTile(icon: category.icon, color: category.color, tint: category.tint)
                VStack(alignment: .leading, spacing: 5) {
                    Text(store.title(category)).font(.system(size: 13, weight: .semibold))
                    Text(store.subtitle(category)).font(.system(size: 11)).foregroundStyle(Palette.muted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 5) {
                    Text(store.report == nil || (store.items(category).isEmpty && store.report?.scannedCategories.contains(category) != true) ? "—" : FileSize.string(store.items(category).reduce(0) { $0 + $1.bytes }))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    Text(store.report == nil ? store.t("等待掃描", "Not scanned") : store.report?.scannedCategories.contains(category) != true ? store.t("未完整掃描", "Not fully scanned") : store.t("\(store.items(category).count) 個項目", "\(store.items(category).count) items"))
                        .font(.system(size: 10)).foregroundStyle(Palette.muted)
                }
                Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(Palette.muted).padding(.leading, 5)
            }.padding(.horizontal, 18).padding(.vertical, 13).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}
