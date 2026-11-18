import Foundation

struct Rate: Sendable {
    let input, read, shortWrite, longWrite, output: Double
    let rule: String
}

struct Pricing: Sendable {
    let models: [String: Rate]

    init(table: String) {
        var entries: [String: Rate] = [:]
        for line in table.split(whereSeparator: \.isNewline) where !line.hasPrefix("#") {
            let fields = line.split(separator: "\t")
            guard fields.count == 7 else { continue }
            let values = fields[1...5].compactMap { Double($0) }
            guard values.count == 5, values.allSatisfy({ $0.isFinite && $0 >= 0 }) else { continue }
            entries[String(fields[0])] = Rate(input: values[0], read: values[1],
                shortWrite: values[2], longWrite: values[3], output: values[4], rule: String(fields[6]))
        }
        models = entries
    }
}

extension Pricing {
    static let standard: Self = {
        let url = Bundle.main.url(forResource: "rates", withExtension: "tsv")
            ?? Bundle.module.url(forResource: "rates", withExtension: "tsv")
        return Self(table: url.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? "")
    }()
}

extension Pricing {
    func rate(for model: String) -> Rate? {
        if let exact = models[model] { return exact }
        let base = model.replacingOccurrences(of: #"-\d{4}-?\d{2}-?\d{2}$"#, with: "", options: .regularExpression)
        return models[base]
    }
}
