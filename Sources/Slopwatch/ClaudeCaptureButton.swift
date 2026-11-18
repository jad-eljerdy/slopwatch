import SwiftUI

struct ClaudeCaptureButton: View {
    let model: DashboardModel
    @State private var enabled = false
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(enabled ? "Disable local limit capture" : "Enable local limit capture") {
                guard let setup = CaptureSetup.local() else { return }
                do { message = try setup.change(enable: !enabled) } catch { message = error.localizedDescription }
                load()
            }
            if let message { Text(message).font(.caption).foregroundStyle(.secondary) }
        }.onAppear { load() }
    }

    private func load() {
        guard let setup = CaptureSetup.local(), let (_, fields) = try? setup.read() else { return }
        enabled = fields.object("statusLine")["command"] as? String == setup.command
    }
}
