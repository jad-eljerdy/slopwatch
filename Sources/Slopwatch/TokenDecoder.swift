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

extension Tokens {
    init(claude values: Fields) {
        let creation = values.object("cache_creation")
        let totalWrite = values.count("cache_creation_input_tokens")
        longWrite = creation.count("ephemeral_1h_input_tokens")
        shortWrite = max(creation.count("ephemeral_5m_input_tokens"), totalWrite - longWrite)
        read = values.count("cache_read_input_tokens")
        input = values.count("input_tokens")
        output = values.count("output_tokens")
    }
}
