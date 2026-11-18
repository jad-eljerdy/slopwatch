import Foundation

extension Tokens {
    init(codex values: Fields) {
        let prompt = values.count("input_tokens")
        read = min(prompt, values.count("cached_input_tokens"))
        shortWrite = min(prompt - read, values.count("cache_write_input_tokens"))
        input = prompt - read - shortWrite
        output = values.count("output_tokens")
    }
}
