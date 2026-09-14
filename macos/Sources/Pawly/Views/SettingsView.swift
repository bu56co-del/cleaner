import SwiftUI

struct SettingsView: View {
    @Bindable var store: AppStore
    var body: some View {
        VStack(alignment: .leading, spacing: 23) {
            HStack(spacing: 14) {
                CatMark().frame(width: 49, height: 49)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pawly").font(.system(size: 27, weight: .bold, design: .rounded))
                    Text(store.t("給你的 Mac，一點溫柔的整理。", "A gentler kind of Mac cleanup.")).font(.system(size: 12)).foregroundStyle(Palette.muted)
                }
            }
            Form {
                Picker(store.t("語言", "Language"), selection: $store.language) {
                    Text("繁體中文").tag("zh")
                    Text("English").tag("en")
                }
                Picker(store.t("外觀", "Appearance"), selection: $store.appearance) {
                    Text(store.t("跟隨系統", "System")).tag("system")
                    Text(store.t("奶油日光", "Cream daylight")).tag("light")
                    Text(store.t("安靜夜晚", "Cozy evening")).tag("dark")
                }
            }.formStyle(.grouped).frame(height: 125)
            VStack(alignment: .leading, spacing: 10) {
                Label(store.t("本機掃描，無需帳戶。", "Local scanning. No account needed."), systemImage: "lock")
                Label(store.t("先預覽再確認；每項功能會說明清理方式。", "Preview first. Each feature explains its recovery options."), systemImage: "checkmark.shield")
                Label(store.t("不會自動清理或在背景常駐。", "No automatic cleanup or background agent."), systemImage: "moon")
            }.font(.system(size: 12)).foregroundStyle(Palette.muted)
            Divider()
            Text(store.t("Pawly 1.2 · 獨立的貓咪介面，採用 Mole 開源引擎（GPL-3.0）及 SwiftTerm（MIT）。並非 Mole 官方 Mac app。", "Pawly 1.2 · An independent cat-themed interface using the Mole engine (GPL-3.0) and SwiftTerm (MIT). Not the official Mole Mac app."))
                .font(.system(size: 10)).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
            Text(store.t("© 2026 Pawly 貢獻者；上游版權屬各原作者。依 GNU GPL v3 提供使用、修改及再發佈權利，並無任何保證。", "© 2026 Pawly contributors; upstream copyrights remain with their authors. Use, modify and redistribute under GNU GPL v3. No warranty."))
                .font(.system(size: 11)).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 18) {
                Button(store.t("授權條款", "License")) {
                    if let url = Bundle.main.url(forResource: "LICENSE", withExtension: nil) { NSWorkspace.shared.open(url) }
                }
                Button(store.t("第三方聲明", "Third-party notices")) {
                    if let url = Bundle.main.resourceURL?.appendingPathComponent("Licenses") { NSWorkspace.shared.open(url) }
                }
                Link(store.t("原始碼", "Source code"), destination: URL(string: "https://github.com/bu56co-del/cleaner")!)
            }.font(.system(size: 12))
        }.padding(28).frame(width: 460).background(Palette.background).foregroundStyle(Palette.ink)
    }
}
