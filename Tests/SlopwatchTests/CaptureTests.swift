import Foundation
import Testing
@testable import Slopwatch

@Test func preserveCommand() throws {
    let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let setup = CaptureSetup(settings: folder.appending(path: "settings.json"), script: folder.appending(path: "helper.sh"))
    let original = Data(#"{"statusLine":{"type":"command","command":"other"},"keep":true}"#.utf8)
    try original.write(to: setup.settings)
    _ = try setup.change(enable: true)
    #expect(try Data(contentsOf: setup.settings) == original)
}

@Test func captureRoundTrip() throws {
    let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let setup = CaptureSetup(settings: folder.appending(path: "settings.json"), script: folder.appending(path: "it's here.sh"))
    _ = try setup.change(enable: true)
    #expect(try setup.read().1.object("statusLine")["command"] as? String == setup.command)
    _ = try setup.change(enable: false)
    #expect(try setup.read().1["statusLine"] == nil)
}
