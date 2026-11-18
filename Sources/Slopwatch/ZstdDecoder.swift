import Foundation
import libzstd

/// One decoder per file preserves the frame state between input chunks.
final class ZstdDecoder {
    private let stream: OpaquePointer
    private var output = [UInt8](repeating: 0, count: ZSTD_DStreamOutSize())
    private var atFrameEnd = false

    init() throws {
        guard let stream = ZSTD_createDStream() else { throw POSIXError(.ENOMEM) }
        self.stream = stream
        guard ZSTD_isError(ZSTD_initDStream(stream)) == 0 else {
            throw CocoaError(.fileReadCorruptFile)
        }
    }

    deinit { ZSTD_freeDStream(stream) }

    func decode(_ chunk: Data, consume: (Data) -> Void) throws {
        try chunk.withUnsafeBytes { source in
            var input = ZSTD_inBuffer(src: source.baseAddress, size: source.count, pos: 0)
            try output.withUnsafeMutableBytes { buffer in
                var full: Bool
                repeat {
                    var destination = ZSTD_outBuffer(dst: buffer.baseAddress, size: buffer.count, pos: 0)
                    let remaining = ZSTD_decompressStream(stream, &destination, &input)
                    guard ZSTD_isError(remaining) == 0 else { throw CocoaError(.fileReadCorruptFile) }
                    if destination.pos > 0 {
                        consume(Data(buffer.prefix(destination.pos)))
                    }
                    atFrameEnd = remaining == 0
                    full = destination.pos == buffer.count
                } while input.pos < input.size || (full && !atFrameEnd)
            }
        }
    }

    func finish() throws {
        guard atFrameEnd else { throw CocoaError(.fileReadCorruptFile) }
    }
}
