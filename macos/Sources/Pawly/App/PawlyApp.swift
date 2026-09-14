import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var store: AppStore?
    private var ending = false
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !ending else { return .terminateLater }
        guard let store else { return .terminateNow }
        let changingFiles = store.cleaning || store.installers.cleaning || store.projects.cleaning || (store.mole.operationActive && store.mole.operation?.preview == false)
        if changingFiles {
            let alert = NSAlert()
            alert.messageText = store.t("操作仍在進行", "An operation is still running")
            alert.informativeText = store.t("停止會保留已完成的變更，未處理的項目不會繼續。", "Stopping keeps changes already completed and leaves remaining items unprocessed.")
            alert.addButton(withTitle: store.t("返回操作", "Keep working"))
            alert.addButton(withTitle: store.t("停止並離開", "Stop and quit"))
            guard alert.runModal() == .alertSecondButtonReturn else { return .terminateCancel }
        }
        ending = true
        store.cancelAllWork()
        Task { @MainActor in
            let deadline = Date().addingTimeInterval(8)
            while (store.waitingForShutdown || OperationConsole.Coordinator.hasActive), Date() < deadline {
                try? await Task.sleep(for: .milliseconds(100))
            }
            let stopped = !store.waitingForShutdown && !OperationConsole.Coordinator.hasActive
            if !stopped {
                ending = false
                store.message = store.t("仍在等候操作停止；請稍後再離開。", "Still waiting for the operation to stop. Try quitting again shortly.")
            }
            NSApp.reply(toApplicationShouldTerminate: stopped)
        }
        return .terminateLater
    }
}

@main
struct PawlyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var store = AppStore()
    var body: some Scene {
        Window("Pawly", id: "main") {
            ContentView(store: store)
                .preferredColorScheme(store.scheme)
                .onAppear { delegate.store = store }
        }
        .defaultSize(width: 1120, height: 790)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu(store.t("整理", "Clean")) {
                Button(store.t("掃描 Mac", "Scan Mac")) { store.scan() }
                    .keyboardShortcut("r", modifiers: .command).disabled(store.busy)
                Button(store.t("探索資料夾", "Explore folder")) { store.page = .disk; store.mole.chooseDiskFolder() }
                    .keyboardShortcut("o", modifiers: .command).disabled(store.busy)
                Button(store.t("開啟垃圾桶", "Open Trash")) { store.openTrash() }
            }
        }
        Settings {
            SettingsView(store: store).preferredColorScheme(store.scheme)
        }
    }
}
