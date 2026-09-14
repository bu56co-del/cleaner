import SwiftUI
import PawlyCore

@MainActor @Observable
final class UninstallStore {
    var report: UninstallReview?
    var app: InstalledApp?
    var loading = false
    var visible = false
    var error: String?
    private var token: CancellationToken?
    func review(_ app: InstalledApp) {
        guard !loading else { return }
        self.app = app; report = nil; error = nil; loading = true; visible = true
        let token = CancellationToken(); self.token = token
        let engine = Bundle.main.resourceURL!.appendingPathComponent("engine")
        Task {
            do { report = try await Task.detached { try UninstallReview.load(app: app, engine: engine, token: token) }.value }
            catch { self.error = error.localizedDescription }
            loading = false
        }
    }
    func cancel() { token?.cancel() }
}
