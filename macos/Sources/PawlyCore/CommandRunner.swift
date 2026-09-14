import Foundation
import Darwin
import PawlySpawn

public struct CommandOutput: Sendable {
    public var data = Data()
    public var error = ""
    public var status: Int32 = -1
    public var cancelled = false
    public var timedOut = false
    public var success: Bool { status == 0 && !cancelled && !timedOut && error.isEmpty }
}

/// Runs on a worker thread. Cancellation kills the complete private process group.
/// No shell interpolation, inherited secrets, authorization, or unbounded buffers.
public struct CommandRunner: Sendable {
    public init() {}
    public static func environment(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [String: String] {
        ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin",
         "HOME": home.path, "USER": NSUserName(), "LOGNAME": NSUserName(),
         "LANG": "en_US.UTF-8", "LC_ALL": "en_US.UTF-8", "TERM": "dumb",
         "NO_COLOR": "1", "MOLE_TEST_NO_AUTH": "1"]
    }
    public func run(_ executable: URL, arguments: [String], environment: [String: String] = Self.environment(),
                    timeout: TimeInterval = 60, token: CancellationToken = CancellationToken(),
                    collect: Bool = true, receive: @Sendable (Data) -> Void = { _ in }) -> CommandOutput {
        var result = CommandOutput()
        if token.isCancelled { result.cancelled = true; return result }
        let argv = ([executable.path] + arguments).map { strdup($0) } + [nil]
        let envp = environment.sorted { $0.key < $1.key }.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer { argv.forEach { free($0) }; envp.forEach { free($0) } }
        var pid: pid_t = 0; var out: Int32 = -1; var err: Int32 = -1
        let code = pawly_spawn(executable.path, argv, envp, &pid, &out, &err)
        guard code == 0 else { result.error = String(cString: strerror(code)); return result }
        defer { close(out); close(err) }
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        var stopAt: TimeInterval?
        var outputTooLarge = false
        var stderr = Data()
        var buffer = [UInt8](repeating: 0, count: 32_768)
        var childStatus: Int32 = 0
        while true {
            let now = ProcessInfo.processInfo.systemUptime
            if stopAt == nil && (token.isCancelled || now >= deadline || outputTooLarge) {
                result.cancelled = token.isCancelled
                result.timedOut = now >= deadline
                stopAt = now
                kill(-pid, SIGTERM)
            }
            if let stopAt, now - stopAt >= 1 { kill(-pid, SIGKILL) }
            var polls = [pollfd(fd: out, events: Int16(POLLIN), revents: 0), pollfd(fd: err, events: Int16(POLLIN), revents: 0)]
            _ = poll(&polls, 2, 50)
            for (index, fd) in [out, err].enumerated() {
                // Bound each drain so a noisy child cannot starve cancellation.
                for _ in 0..<16 {
                    let count = read(fd, &buffer, buffer.count)
                    guard count > 0 else { break }
                    let chunk = Data(buffer.prefix(count))
                    if index == 0 {
                        receive(chunk)
                        if collect {
                            if result.data.count + count <= 16 * 1024 * 1024 { result.data.append(chunk) }
                            else { outputTooLarge = true }
                        }
                    } else if stderr.count < 512 * 1024 { stderr.append(chunk) }
                }
            }
            // waitid observes exit without reaping, preserving ownership of the PID
            // until the private group has been stopped and remaining output drained.
            var info = siginfo_t()
            let ended = waitid(P_PID, id_t(pid), &info, WEXITED | WNOHANG | WNOWAIT)
            if ended == 0 && info.si_pid == pid {
                kill(-pid, SIGKILL)
                for (index, fd) in [out, err].enumerated() {
                    while true {
                        let count = read(fd, &buffer, buffer.count)
                        guard count > 0 else { break }
                        let chunk = Data(buffer.prefix(count))
                        if index == 0 {
                            receive(chunk)
                            if collect && result.data.count + count <= 16 * 1024 * 1024 { result.data.append(chunk) }
                        } else if stderr.count < 512 * 1024 { stderr.append(chunk) }
                    }
                }
                _ = waitpid(pid, &childStatus, 0)
                result.status = (childStatus & 0x7f) == 0 ? (childStatus >> 8) & 0xff : 128 + (childStatus & 0x7f)
                break
            }
            if ended != 0 && errno != EINTR {
                kill(-pid, SIGKILL); _ = waitpid(pid, &childStatus, 0)
                result.error = "Could not observe command completion"; break
            }
        }
        if outputTooLarge { result.error = "Command output exceeded the 16 MB limit" }
        else if result.timedOut { result.error = "Command timed out; incomplete output was discarded" }
        else if result.cancelled { result.error = "Command cancelled" }
        else if result.status != 0 { result.error = String(decoding: stderr, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines) }
        if result.status != 0 && result.error.isEmpty { result.error = "Command exited with status \(result.status)" }
        if !result.success { result.data = Data() }
        return result
    }
}
