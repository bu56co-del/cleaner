import SwiftUI
import PawlyCore

struct OperationView: View {
    @Bindable var store: AppStore
    @Bindable var mole: MoleStore
    @State private var confirmation = false
    @State private var stopNonce = 0
    @State private var inputNonce = 0
    @State private var input = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let action = mole.pendingAction {
                HStack(alignment: .top) {
                    IconTile(icon: action.icon)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(action.title(zh: store.language == "zh")).font(.system(size: 24, weight: .semibold, design: .rounded))
                        Text(action.detail(zh: store.language == "zh")).font(.system(size: 12)).foregroundStyle(Palette.muted)
                    }
                    Spacer()
                    if mole.operationActive {
                        ProgressView().controlSize(.small)
                        Button(store.t("停止操作", "Stop operation")) { mole.operationCancelled = true; stopNonce += 1 }
                            .buttonStyle(PawButtonStyle(prominent: false))
                    }
                }
                if let error = mole.launchError { InlineError(text: error) }
                if let target = mole.pendingTarget, action != .optimize {
                    Text(target).font(.system(size: 11, design: .monospaced)).textSelection(.enabled).lineLimit(2)
                }
                if let request = mole.operation, request.action == action, request.target == mole.pendingTarget {
                    HStack {
                        Label(mole.operationFinished ? store.t("操作結果", "Result") : request.preview ? store.t("預覽模式 · 不會清理檔案", "Preview · No cleanup changes") : store.t("正在執行已選操作", "Selected operation"), systemImage: request.preview ? "eye" : "play.circle")
                            .foregroundStyle(request.preview ? Palette.sage : Palette.coral)
                        Spacer()
                        if mole.operationFinished {
                            Text(mole.operationCancelled ? store.t("已停止", "Stopped") : mole.operationExit == 0 ? store.t("引擎已結束；請查看下面結果", "Engine ended; review the result below") : store.t("操作未完成", "Operation did not complete"))
                        }
                    }.font(.system(size: 11))
                    OperationConsole(request: request, root: mole.engineRoot, stopNonce: stopNonce, inputNonce: inputNonce, input: input) { code in
                        mole.endOperation(request.id, exitCode: code)
                    }.id(request.id).frame(minHeight: 280)
                    HStack(spacing: 7) {
                        key("↑", "\u{1b}[A"); key("↓", "\u{1b}[B")
                        key(store.t("空白鍵 · 勾選", "Space · Select"), " ")
                        key(store.t("Enter · 確認", "Enter · Confirm"), "\r")
                        key("Esc", "\u{1b}")
                        Spacer()
                        Label(store.t("可直接用鍵盤", "Keyboard ready"), systemImage: "keyboard").foregroundStyle(Palette.muted)
                    }.font(.system(size: 11)).disabled(!mole.operationActive)
                    if mole.operationFinished {
                        HStack {
                            Button(store.t("重新預覽", "Preview again")) { mole.launch(preview: true) }.buttonStyle(PawButtonStyle(prominent: false))
                            Spacer()
                            if action.supportsPreview || action == .touchID, request.preview, mole.operationExit == 0, !mole.operationCancelled {
                                Button(store.t("查看執行確認", "Review execution")) { confirmation = true }.buttonStyle(PawButtonStyle())
                            }
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 23) {
                        HStack(alignment: .top, spacing: 18) {
                            CatMark().frame(width: 60, height: 60)
                            VStack(alignment: .leading, spacing: 10) {
                                Text(store.t("先睇清楚，再落手。", "A closer look before the next step.")).font(.system(size: 22, weight: .semibold, design: .rounded))
                                Text(action.impact(zh: store.language == "zh")).font(.system(size: 13)).lineSpacing(5).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Divider()
                        Text(store.t("下方會顯示完整原引擎操作畫面，保留選擇項目、路徑檢查及最後確認。按鈕和鍵盤都可以操作。", "The embedded engine preserves item selection, path checks and final confirmation. Use the buttons or your keyboard."))
                            .foregroundStyle(Palette.muted).font(.system(size: 12))
                        if let summary = mole.nativePreviewSummary {
                            ScrollView { Text(summary).font(.system(size: 12)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(maxHeight: 180)
                            Button(store.t("查看執行確認", "Review execution")) { confirmation = true }.buttonStyle(PawButtonStyle())
                        } else if action.supportsPreview || action == .touchID {
                            Button(store.t("開始預覽", "Start preview")) { mole.launch(preview: true) }.buttonStyle(PawButtonStyle())
                        } else {
                            Button(store.t("開啟", "Open")) { mole.launch(preview: false) }.buttonStyle(PawButtonStyle())
                        }
                    }.padding(28).pawCard()
                    Spacer()
                }
            } else {
                Text(store.t("由左邊選擇一項功能開始。", "Choose a feature from the sidebar to begin.")).foregroundStyle(Palette.muted)
            }
        }.padding(25)
        .sheet(isPresented: $confirmation) {
            if let action = mole.pendingAction {
                VStack(alignment: .leading, spacing: 22) {
                    Label(action.title(zh: store.language == "zh"), systemImage: action.icon).font(.system(size: 24, weight: .semibold, design: .rounded))
                    Text(action.impact(zh: store.language == "zh")).lineSpacing(5)
                    if let target = mole.nativePreviewSummary ?? mole.pendingTarget { ScrollView { Text(target).font(.system(size: 11)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(maxHeight: 190) }
                    Text(action == .optimize ? store.t("按「開始執行」後，只會運行上面列出的項目；引擎會重新檢查現況，並在需要時要求授權。", "Start operation runs only the tasks listed above. The engine rechecks current conditions and requests authorization when needed.") : store.t("開始後，請依引擎顯示檢查最終項目及確認。", "After starting, review the final items and confirmation shown by the engine.")).foregroundStyle(Palette.muted)
                    HStack {
                        Button(store.t("返回", "Go back")) { confirmation = false }.keyboardShortcut(.cancelAction)
                        Spacer()
                        Button(store.t("開始執行", "Start operation")) { confirmation = false; mole.launch(preview: false) }.buttonStyle(PawButtonStyle())
                    }
                }.padding(30).frame(width: 520).background(Palette.background)
            }
        }
    }
    private func key(_ title: String, _ data: String) -> some View {
        Button(title) { input = data; inputNonce += 1 }.buttonStyle(.bordered)
    }
}
