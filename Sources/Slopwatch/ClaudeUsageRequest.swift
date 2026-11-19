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
            let request = #"{"type":"control_request","request_id":"slopwatch-quota","request":{"subtype":"get_usage","skip_behaviors":true}}"#
            try writer.write(contentsOf: Data((request + "\n").utf8))
            try writer.close()
            return receive(from: output.fileHandleForReading)
        } catch { return nil }
    }

    private static func receive(from handle: FileHandle) -> Quota? {
        let deadline = ContinuousClock.now + .seconds(8)
        var pending = Data()
        while let line = CLIResponseLine.read(handle, buffer: &pending, until: deadline) {
            if let reading = reading(from: line, observed: Date()) { return reading }
        }
        return nil
    }
}
