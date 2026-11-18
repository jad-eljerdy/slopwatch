import Darwin
import Foundation

enum ClaudeUsageRequest {
    private static let identifier = "slopwatch-quota"

    static func reading(from line: Data, observed: Date) -> Quota? {
        guard let message = try? JSONSerialization.jsonObject(with: line) as? Fields,
              message["type"] as? String == "control_response" else { return nil }
        let response = message.object("response")
        guard response["request_id"] as? String == identifier, response["subtype"] as? String == "success" else { return nil }
        let usage = response.object("response")
        guard var reading = ClaudeQuota.parse(usage.object("rate_limits"), observed: observed) else { return nil }
        reading.plan = usage["subscription_type"] as? String
        return reading
    }

    static func fetch(paths: LocalPaths) -> Quota? {
        guard let executable = paths.executable("claude") else { return nil }
        let task = Process()
        let input = Pipe()
        let output = Pipe()
        task.executableURL = executable
        task.currentDirectoryURL = URL(filePath: "/")
        task.arguments = ["-p", "--safe-mode", "--strict-mcp-config", "--tools", "", "--no-session-persistence",
                          "--input-format", "stream-json", "--output-format", "stream-json", "--verbose"]
        var env = paths.environment
        for flag in ["DISABLE_TELEMETRY", "DISABLE_ERROR_REPORTING", "DISABLE_AUTOUPDATER", "CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY"] {
            env[flag] = "1"
        }
        env["OTEL_SDK_DISABLED"] = "true"
        env["CLAUDE_CODE_ENABLE_TELEMETRY"] = "0"
        task.environment = env
        task.standardInput = input
        task.standardOutput = output
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            defer {
                try? input.fileHandleForWriting.close()
                try? output.fileHandleForReading.close()
                if task.isRunning { kill(task.processIdentifier, SIGKILL) }
                task.waitUntilExit()
            }
            let writer = input.fileHandleForWriting
            _ = fcntl(writer.fileDescriptor, F_SETNOSIGPIPE, 1)
            let request = #"{"type":"control_request","request_id":"slopwatch-quota","request":{"subtype":"get_usage"}}"#
            try writer.write(contentsOf: Data((request + "\n").utf8))
            try writer.close()
            return receive(from: output.fileHandleForReading)
        } catch { return nil }
    }

    private static func receive(from handle: FileHandle) -> Quota? {
        let deadline = ContinuousClock.now + .seconds(8)
        var descriptor = pollfd(fd: handle.fileDescriptor, events: Int16(POLLIN), revents: 0)
        var buffer = [UInt8](repeating: 0, count: 8192)
        var pending = Data()
        var result: Quota?
        while ContinuousClock.now < deadline {
            let ready = poll(&descriptor, 1, 100)
            if ready < 0 && errno != EINTR { break }
            guard ready > 0 else { continue }
            let count = buffer.withUnsafeMutableBytes { Darwin.read(handle.fileDescriptor, $0.baseAddress, $0.count) }
            guard count > 0 else { break }
            pending.append(contentsOf: buffer.prefix(count))
            while let end = pending.firstIndex(of: 10) {
                if let quota = reading(from: pending[..<end], observed: Date()) { result = quota }
                pending.removeSubrange(...end)
            }
            if pending.count > 1_048_576 { break }
        }
        return result
    }
}
