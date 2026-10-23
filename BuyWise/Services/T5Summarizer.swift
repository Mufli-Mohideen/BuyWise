import CoreML
import Foundation

/// Runs the fine-tuned T5-small model on device: encode once, then decode one token at a time.
nonisolated final class T5Summarizer: @unchecked Sendable {
    /// Fixed lengths set when the models were converted.
    static let maxInputTokens = 256
    static let maxOutputTokens = 96

    /// Loaded on first use; nil if the models are missing from the bundle.
    static let shared: T5Summarizer? = try? T5Summarizer()

    private let encoder: MLModel
    private let decoder: MLModel
    private let tokenizer: UnigramTokenizer

    private init() throws {
        func resource(_ name: String, _ ext: String) throws -> URL {
            guard let url = Bundle.main.url(forResource: name, withExtension: ext) else { throw CocoaError(.fileNoSuchFile) }
            return url
        }
        let configuration = MLModelConfiguration()
        // The models compute in float32 (T5 can overflow in float16), which the GPU and CPU handle.
        configuration.computeUnits = .cpuAndGPU 
        encoder = try MLModel(contentsOf: resource("SummaryEncoder", "mlmodelc"), configuration: configuration)
        decoder = try MLModel(contentsOf: resource("SummaryDecoder", "mlmodelc"), configuration: configuration)
        tokenizer = try UnigramTokenizer(vocabulary: resource("SummaryVocab", "json"))
    }

    func summarize(_ text: String) throws -> String {
        var ids = tokenizer.encode(text)
        if ids.count > Self.maxInputTokens { ids = Array(ids.prefix(Self.maxInputTokens - 1)) + [UnigramTokenizer.endOfText] }

        let inputIDs = try Self.zeros(Self.maxInputTokens)
        let mask = try Self.zeros(Self.maxInputTokens)
        for (index, id) in ids.enumerated() {
            inputIDs[index] = NSNumber(value: id)
            mask[index] = 1
        }
        let encoded = try encoder.prediction(from: MLDictionaryFeatureProvider(dictionary: [
            "input_ids": inputIDs, "attention_mask": mask,
        ]))
        guard let hidden = encoded.featureValue(for: "hidden_states")?.multiArrayValue else { throw CocoaError(.coderValueNotFound) }

        // The decoder input starts with the pad token (T5's start token) and grows by one token per step.
        let output = try Self.zeros(Self.maxOutputTokens)
        let position = try Self.zeros(1)
        var tokens: [Int] = []
        for step in 0..<(Self.maxOutputTokens - 1) {
            position[0] = NSNumber(value: step)
            let result = try decoder.prediction(from: MLDictionaryFeatureProvider(dictionary: [
                "decoder_input_ids": output, "encoder_hidden_states": hidden,
                "encoder_attention_mask": mask, "position": position,
            ]))
            guard let token = result.featureValue(for: "next_token")?.multiArrayValue?[0].intValue,
                  token != UnigramTokenizer.endOfText else { break }
            tokens.append(token)
            output[step + 1] = NSNumber(value: token)
        }
        return tokenizer.decode(tokens)
    }

    private static func zeros(_ count: Int) throws -> MLMultiArray {
        let array = try MLMultiArray(shape: count == 1 ? [1] : [1, NSNumber(value: count)], dataType: .int32)
        for index in 0..<count { array[index] = 0 }
        return array
    }
}

/// T5's SentencePiece unigram tokenizer, matching the Hugging Face tokenizer used in training.
nonisolated struct UnigramTokenizer {
    static let pad = 0
    static let endOfText = 1
    static let unknown = 2

    private let pieces: [String]
    private let lookup: [String: (id: Int, score: Double)]
    private let longestPiece: Int
    private let unknownScore: Double

    init(vocabulary url: URL) throws {
        guard let entries = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [[Any]] else {
            throw CocoaError(.coderReadCorrupt)
        }
        var pieces: [String] = []
        var lookup: [String: (Int, Double)] = [:]
        var minScore = 0.0
        for (id, entry) in entries.enumerated() {
            let piece = entry[0] as? String ?? ""
            let score = (entry[1] as? NSNumber)?.doubleValue ?? 0
            pieces.append(piece)
            lookup[piece] = (id, score)
            minScore = min(minScore, score)
        }
        self.pieces = pieces
        self.lookup = lookup
        longestPiece = pieces.map { $0.unicodeScalars.count }.max() ?? 1
        unknownScore = minScore - 10
    }

    func encode(_ text: String) -> [Int] {
        let normalized = text.precomposedStringWithCompatibilityMapping
        var ids: [Int] = []
        for word in normalized.split(whereSeparator: \.isWhitespace) {
            ids += segment(Array(("▁" + word).unicodeScalars))
        }
        return ids + [Self.endOfText]
    }

    func decode(_ ids: [Int]) -> String {
        ids.filter { $0 > Self.unknown && $0 < pieces.count }
            .map { pieces[$0] }
            .joined()
            .replacingOccurrences(of: "▁", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    /// Best-scoring split of one word into vocabulary pieces.
    private func segment(_ scalars: [Unicode.Scalar]) -> [Int] {
        let count = scalars.count
        var best = [Double](repeating: -.infinity, count: count + 1)
        var from = [Int](repeating: 0, count: count + 1)
        var token = [Int](repeating: Self.unknown, count: count + 1)
        best[0] = 0
        for end in 1...count {
            for start in max(0, end - longestPiece)..<end where best[start] > -.infinity {
                var piece = String.UnicodeScalarView()
                piece.append(contentsOf: scalars[start..<end])
                guard let match = lookup[String(piece)] else { continue }
                if best[start] + match.score > best[end] {
                    best[end] = best[start] + match.score
                    from[end] = start
                    token[end] = match.id
                }
            }
            // A character no piece covers becomes the unknown token.
            if best[end] == -.infinity {
                best[end] = best[end - 1] + unknownScore
                from[end] = end - 1
                token[end] = Self.unknown
            }
        }
        var ids: [Int] = []
        var position = count
        while position > 0 {
            if !(token[position] == Self.unknown && ids.last == Self.unknown) { ids.append(token[position]) }
            position = from[position]
        }
        return ids.reversed()
    }
}
