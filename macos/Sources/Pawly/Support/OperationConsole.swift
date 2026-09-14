import SwiftUI
import PawlyCore
@preconcurrency import SwiftTerm

/// SwiftUI's surrounding buttons retain focus unless the AppKit terminal
/// explicitly takes it. Keep keyboard routing local to this terminal window.
final class PawlyTerminalView: TerminalView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in self?.focusKeyboard() }
    }

    override func mouseDown(with event: NSEvent) {
        focusKeyboard()
        super.mouseDown(with: event)
    }

    func focusKeyboard() {
        guard let window, window.attachedSheet == nil else { return }
        window.makeFirstResponder(self)
    }
}

/// AppKit is limited to the terminal surface; workflow state remains in MoleStore.
struct OperationConsole: NSViewRepresentable {
    let request: OperationRequest
    let root: URL
    let stopNonce: Int
    let inputNonce: Int
    let input: String
    let ended: (Int32?) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(ended: ended) }
    func makeNSView(context: Context) -> PawlyTerminalView {
        let view = PawlyTerminalView(frame: NSRect(x: 0, y: 0, width: 900, height: 440), font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular))
        view.nativeBackgroundColor = NSColor(srgbRed: 0.12, green: 0.115, blue: 0.11, alpha: 1)
        view.nativeForegroundColor = NSColor(srgbRed: 0.94, green: 0.9, blue: 0.85, alpha: 1)
        view.terminalDelegate = context.coordinator
        context.coordinator.view = view
        context.coordinator.lastStop = stopNonce
        context.coordinator.lastInput = inputNonce
        context.coordinator.start(request, root: root)
        return view
    }
    func updateNSView(_ nsView: PawlyTerminalView, context: Context) {
        if context.coordinator.lastStop != stopNonce { context.coordinator.lastStop = stopNonce; context.coordinator.stop() }
        if context.coordinator.lastInput != inputNonce {
            context.coordinator.lastInput = inputNonce
            context.coordinator.process?.send(data: Array(input.utf8)[...])
            nsView.focusKeyboard()
        }
    }
    static func dismantleNSView(_ view: PawlyTerminalView, coordinator: Coordinator) { coordinator.stop() }

    @MainActor final class Coordinator: NSObject, @preconcurrency TerminalViewDelegate, @preconcurrency LocalProcessDelegate {
        private static var active: [UUID: Coordinator] = [:]
        private let sessionID = UUID()
        static var hasActive: Bool { !active.isEmpty }
        static func stopAll() { for coordinator in active.values { coordinator.stop() } }
        weak var view: TerminalView?
        var process: LocalProcess?
        var lastStop = 0
        var lastInput = 0
        var finished = false
        var stopping = false
        let ended: (Int32?) -> Void
        private var watchdog: Task<Void, Never>?
        init(ended: @escaping (Int32?) -> Void) { self.ended = ended }
        func start(_ request: OperationRequest, root: URL) {
            Self.active[sessionID] = self
            let child = LocalProcess(delegate: self)
            process = child
            var environment = CommandRunner.environment()
            environment["TERM"] = "xterm-256color"
            environment["COLORTERM"] = "truecolor"
            environment.removeValue(forKey: "NO_COLOR")
            if !request.preview { environment.removeValue(forKey: "MOLE_TEST_NO_AUTH") }
            child.startProcess(executable: "/bin/bash", args: [root.appendingPathComponent("pawly-console.sh").path] + request.arguments,
                               environment: environment.map { "\($0.key)=\($0.value)" }, currentDirectory: root.path)
            guard child.shellPid > 1 else { processTerminated(child, exitCode: nil); return }
            watchdog = Task { [weak self] in
                try? await Task.sleep(for: .seconds(1800))
                guard !Task.isCancelled else { return }
                self?.stop()
            }
        }
        func stop() {
            guard !finished, !stopping, let process, process.shellPid > 1 else { return }
            stopping = true
            let pid = process.shellPid
            // forkpty owns this session; signal only its current foreground and root groups.
            let foreground = tcgetpgrp(process.childfd)
            if foreground > 1, foreground != getpgrp() { kill(-foreground, SIGINT) }
            if pid > 1, getpgid(pid) == pid { kill(-pid, SIGTERM) }
            // SwiftTerm 1.20's terminate() cancels its exit observer before
            // delivering processTerminated. Signal the owned group ourselves
            // and keep the observer alive until it reports/reaps the child.
            Task { [self] in
                try? await Task.sleep(for: .seconds(2))
                guard !self.finished,
                      self.process?.shellPid == pid, getpgid(pid) == pid else { return }
                kill(-pid, SIGKILL)
            }
        }
        func processTerminated(_ source: LocalProcess, exitCode: Int32?) {
            guard !finished else { return }
            finished = true; watchdog?.cancel()
            Self.active.removeValue(forKey: sessionID)
            // This pinned SwiftTerm release supplies waitpid's raw wait status.
            let normalized = exitCode.map { ($0 & 0x7f) == 0 ? ($0 >> 8) & 0xff : 128 + ($0 & 0x7f) }
            ended(normalized)
        }
        func dataReceived(slice: ArraySlice<UInt8>) { view?.feed(byteArray: slice) }
        func getWindowSize() -> winsize {
            let terminal = view?.getTerminal()
            return winsize(ws_row: UInt16(clamping: terminal?.rows ?? 24), ws_col: UInt16(clamping: terminal?.cols ?? 100), ws_xpixel: 0, ws_ypixel: 0)
        }
        func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
            guard let process, process.running else { return }
            var size = getWindowSize()
            _ = PseudoTerminalHelpers.setWinSize(masterPtyDescriptor: process.childfd, windowSize: &size)
        }
        func send(source: TerminalView, data: ArraySlice<UInt8>) { process?.send(data: data) }
        func setTerminalTitle(source: TerminalView, title: String) {}
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
        func scrolled(source: TerminalView, position: Double) {}
        func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}
        func clipboardCopy(source: TerminalView, content: Data) {}
        func clipboardRead(source: TerminalView) -> Data? { nil }
        func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {}
    }
}
