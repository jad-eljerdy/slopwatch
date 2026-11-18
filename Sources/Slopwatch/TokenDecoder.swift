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

extension Tokens {
    func since(_ old: Tokens?) -> Self {
        guard let old, total >= old.total else { return self }
        return Self(input: max(0, input - old.input), read: max(0, read - old.read),
                    shortWrite: max(0, shortWrite - old.shortWrite), longWrite: max(0, longWrite - old.longWrite),
                    output: max(0, output - old.output))
    }
}
