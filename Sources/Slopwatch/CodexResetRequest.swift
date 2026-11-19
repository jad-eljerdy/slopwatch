import Darwin
import Foundation

enum CodexResetRequest {
    static func fetch(paths: LocalPaths) -> BankedResets? {
        guard let executable = paths.executable("codex") else { return nil }
        let process = Process()
        let input = Pipe()
        let output = Pipe()
        process.executableURL = executable
        process.arguments = ["app-server", "-c", "analytics.enabled=false", "-c", "otel.exporter=\"none\""]
        process.environment = paths.environment
        process.currentDirectoryURL = URL(filePath: "/")
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            defer {
                try? input.fileHandleForWriting.close()
                try? output.fileHandleForReading.close()
                if process.isRunning { kill(process.processIdentifier, SIGKILL) }
                process.waitUntilExit()
            }
            let writer = input.fileHandleForWriting
            _ = fcntl(writer.fileDescriptor, F_SETNOSIGPIPE, 1)
            func send(_ message: String) throws {
                try writer.write(contentsOf: Data((message + "\n").utf8))
            }
            try send(#"{"id":1,"method":"initialize","params":{"clientInfo":{"name":"slopwatch","version":"1"},"capabilities":{"experimentalApi":true}}}"#)
            var buffer = Data()
            let deadline = ContinuousClock.now + .seconds(8)
            while let line = CLIResponseLine.read(output.fileHandleForReading, buffer: &buffer, until: deadline) {
                guard let row = try? JSONSerialization.jsonObject(with: line) as? Fields else { continue }
                switch row["id"] as? Int {
                case 1:
                    guard row["result"] is Fields else { return nil }
                    try send(#"{"method":"initialized"}"#)
                    try send(#"{"id":2,"method":"account/rateLimits/read"}"#)
                case 2: return BankedResets.codex(row.object("result").object("rateLimitResetCredits"))
                default: continue
                }
            }
        } catch {}
        return nil
    }
}
