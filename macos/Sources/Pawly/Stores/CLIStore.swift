import SwiftUI
import PawlyCore

@MainActor @Observable
final class CLIStore {
    struct Installation: Identifiable { let path: String; let identity: String; let version: String; var id: String { path } }
    var installations: [Installation] = []
    var loading = false
    private var token: CancellationToken?
    func cancel() { token?.cancel() }
    func refresh() {
        guard !loading else { return }
        let candidates = ["/opt/homebrew/bin/mo", "/opt/homebrew/bin/mole", "/usr/local/bin/mo", "/usr/local/bin/mole", FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin/mo").path, FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin/mole").path]
        loading = true
        let token = CancellationToken(); self.token = token
        Task {
            installations = await Task.detached {
                var result: [Installation] = []; var seen: Set<String> = []
                for candidate in candidates {
                    let url = URL(fileURLWithPath: candidate).resolvingSymlinksInPath()
                    guard !token.isCancelled, !url.path.contains(".app/"), FileManager.default.isExecutableFile(atPath: url.path), seen.insert(url.path).inserted,
                          let identity = try? FileIdentity.read(url) else { continue }
                    let output = CommandRunner().run(url, arguments: ["--version"], timeout: 5, token: token)
                    let version = String(decoding: output.data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                    guard output.success, version.localizedCaseInsensitiveContains("mole") else { continue }
                    result.append(Installation(path: url.path, identity: identity.shellIdentity, version: version))
                }
                return result
            }.value
            loading = false
        }
    }
}
