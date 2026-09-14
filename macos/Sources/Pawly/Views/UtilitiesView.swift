import SwiftUI
import PawlyCore

struct UtilitiesView: View {
    @Bindable var store: AppStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeading(title: store.t("工具與設定", "Tools & settings"), subtitle: store.t("保留清單、掃描位置及授權設定。", "Exclusions, scan locations and authorization settings."))
                ForEach([EngineAction.cleanWhitelist, .optimizeWhitelist, .purgePaths, .touchID, .completion]) { action in
                    HStack(spacing: 16) {
                        IconTile(icon: action.icon, color: Palette.lavender, tint: Palette.lavenderTint)
                        VStack(alignment: .leading, spacing: 7) {
                            Text(action.title(zh: store.language == "zh")).font(.system(size: 16, weight: .semibold, design: .rounded))
                            Text(action.detail(zh: store.language == "zh")).font(.system(size: 12)).foregroundStyle(Palette.muted)
                        }
                        Spacer()
                        Button(store.t("開啟", "Open")) { store.openOperation(action) }.buttonStyle(PawButtonStyle(prominent: false)).disabled(store.busy)
                    }.padding(20).pawCard()
                }
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Label(store.t("Mole 指令版管理", "Mole CLI management"), systemImage: "terminal").font(.system(size: 17, weight: .semibold, design: .rounded))
                        Spacer()
                        Button(store.t("重新檢查", "Refresh")) { store.cli.refresh() }.disabled(store.cli.loading)
                    }
                    if store.cli.loading { ProgressView() }
                    else if store.cli.installations.isEmpty {
                        Text(store.t("未找到獨立安裝的 Mole 指令版。Pawly 已內附引擎，仍可直接使用以上功能。", "No separate Mole CLI installation was found. Pawly's bundled engine already supports the features above.")).font(.system(size: 12)).foregroundStyle(Palette.muted)
                    }
                    ForEach(store.cli.installations) { cli in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(cli.version).font(.system(size: 12)).textSelection(.enabled)
                            Text(cli.path).font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted).textSelection(.enabled)
                            HStack {
                                Button(store.t("檢查並更新…", "Review update…")) { store.openOperation(.cliUpdate, target: cli.path) }
                                Button(store.t("預覽移除…", "Preview removal…")) { store.openOperation(.cliRemove, target: cli.path) }
                            }.buttonStyle(.bordered).disabled(store.busy)
                        }
                    }
                }.padding(20).pawCard()
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pawly 1.2 · Mole 1.53.0").fontWeight(.semibold)
                        Text(store.t("Pawly 內附引擎，開啟即可使用。CLI 自我更新與移除不會作用於此 App 的隨附資源。", "Pawly includes its engine. CLI self-update and removal must target a separate CLI installation."))
                            .font(.system(size: 12)).foregroundStyle(Palette.muted)
                    }
                    Spacer()
                    SettingsLink { Text(store.t("外觀與語言", "Appearance & language")) }.buttonStyle(PawButtonStyle(prominent: false))
                }.padding(20).pawCard()
            }.padding(28)
        }.task { store.cli.refresh() }
    }
}
