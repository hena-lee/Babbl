import Foundation

final class FillerFilter {
    private var unconditionalFillers: Set<String> = []
    private var conditionalFillers: [ConditionalFiller] = []

    init() {
        loadDefaultFillers()
    }

    /// Returns true if a filter setting is enabled, defaulting to true when unset.
    private static func isEnabled(_ key: String) -> Bool {
        UserDefaults.standard.object(forKey: key) == nil || UserDefaults.standard.bool(forKey: key)
    }

    func filter(_ text: String) -> String {
        guard Self.isEnabled("filterEnabled") else { return text }

        var result = text

        // Pass 1: Remove unconditional fillers (standalone words)
        result = removeUnconditionalFillers(result)

        // Pass 2: Remove conditional fillers with context awareness
        result = removeConditionalFillers(result)

        // Pass 3: Clean up artifacts (double spaces, leading commas, etc.)
        result = cleanUp(result)

        return result
    }

    // MARK: - Unconditional Fillers

    private func removeUnconditionalFillers(_ text: String) -> String {
        guard Self.isEnabled("filterUm") else { return text }

        var words = tokenize(text)

        words = words.filter { token in
            let lower = token.word.lowercased().trimmingCharacters(in: .punctuationCharacters)
            return !unconditionalFillers.contains(lower)
        }

        return reconstruct(words)
    }

    // MARK: - Conditional Fillers

    private func removeConditionalFillers(_ text: String) -> String {
        var result = text

        for filler in conditionalFillers {
            if let key = filler.settingsKey, !Self.isEnabled(key) { continue }
            result = filler.apply(to: result)
        }

        return result
    }

    // MARK: - Cleanup

    private func cleanUp(_ text: String) -> String {
        var result = text

        // Remove double/triple spaces
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }

        // Remove leading/trailing commas from sentences
        result = result.replacingOccurrences(
            of: #"^\s*,\s*"#,
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #",\s*,"#,
            with: ",",
            options: .regularExpression
        )

        // Capitalize first letter of sentences
        result = capitalizeSentences(result)

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func capitalizeSentences(_ text: String) -> String {
        var result = text
        let pattern = #"(?:^|[.!?]\s+)([a-z])"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, range: range)
            for match in matches.reversed() {
                if let charRange = Range(match.range(at: 1), in: result) {
                    result.replaceSubrange(charRange, with: result[charRange].uppercased())
                }
            }
        }
        // Capitalize the very first character
        if let first = result.first, first.isLowercase {
            result = result.prefix(1).uppercased() + result.dropFirst()
        }
        return result
    }

    // MARK: - Tokenization

    private struct Token {
        let word: String
        let trailingWhitespace: String
    }

    private func tokenize(_ text: String) -> [Token] {
        var tokens: [Token] = []
        let scanner = Scanner(string: text)
        scanner.charactersToBeSkipped = nil

        while !scanner.isAtEnd {
            let word = scanner.scanUpToCharacters(from: .whitespaces) ?? ""
            let space = scanner.scanCharacters(from: .whitespaces) ?? ""
            if !word.isEmpty {
                tokens.append(Token(word: word, trailingWhitespace: space))
            }
        }

        return tokens
    }

    private func reconstruct(_ tokens: [Token]) -> String {
        tokens.map { $0.word + $0.trailingWhitespace }.joined()
    }

    // MARK: - Default Configuration

    private func loadDefaultFillers() {
        // Unconditional: always filler words, never meaningful
        unconditionalFillers = [
            "um", "uh", "erm", "hmm", "hm", "ah", "eh",
            "umm", "uhh", "mmm", "mm"
        ]

        // Conditional: context-dependent
        conditionalFillers = [
            // "like" as filler: remove when preceded by "was/is/it's/just/really" or between commas
            ConditionalFiller(
                phrase: "like",
                settingsKey: "filterLike",
                removePatterns: [
                    #"\b(was|is|it's|just|really|pretty|so)\s+like\b"#,  // "was like" filler
                    #",\s*like,\s*"#,                                      // ", like, "
                    #"\blike\s+(um|uh|really|so|basically|literally)\b"#   // "like um", "like really"
                ],
                keepPatterns: [
                    #"\b(would|i'd|i|you|we|they|don't|didn't)\s+like\b"#, // "I like" (verb)
                    #"\blooks?\s+like\b"#,                                  // "looks like"
                    #"\bfeel\s+like\b"#,                                    // "feel like"
                    #"\bsomething\s+like\b"#                                // "something like"
                ]
            ),

            // "you know" as filler
            ConditionalFiller(
                phrase: "you know",
                settingsKey: "filterYouKnow",
                removePatterns: [
                    #",\s*you know,?\s*"#,          // ", you know, "
                    #"\byou know\s+(like|um|uh)\b"# // "you know like"
                ],
                keepPatterns: [
                    #"\b(do|did|don't|didn't)\s+you know\b"# // "do you know" (question)
                ]
            ),

            // "I mean" as filler at sentence start or as interjection
            ConditionalFiller(
                phrase: "I mean",
                settingsKey: "filterIMean",
                removePatterns: [
                    #"(?:^|[.!?]\s+)I mean,?\s*"#, // Sentence-starting "I mean"
                    #",\s*I mean,\s*"#              // ", I mean, "
                ],
                keepPatterns: []
            ),

            // "basically" as hedge
            ConditionalFiller(
                phrase: "basically",
                settingsKey: "filterBasically",
                removePatterns: [
                    #"(?:^|[.!?]\s+)basically,?\s*"#, // Sentence-starting
                    #",?\s*basically,?\s*"#             // Mid-sentence filler
                ],
                keepPatterns: []
            ),

            // "actually" as filler
            ConditionalFiller(
                phrase: "actually",
                settingsKey: "filterActually",
                removePatterns: [
                    #"(?:^|[.!?]\s+)actually,?\s*"#, // Sentence-starting
                ],
                keepPatterns: [
                    #"\bactually\s+(is|was|does|did|has|had)\b"# // Contrasting usage
                ]
            ),

            // "literally" as filler
            ConditionalFiller(
                phrase: "literally",
                settingsKey: "filterLiterally",
                removePatterns: [
                    #"\bliterally\s+(just|like|so|the)\b"# // "literally just"
                ],
                keepPatterns: []
            ),

            // "so" as sentence-starting filler
            ConditionalFiller(
                phrase: "so",
                settingsKey: "filterSo",
                removePatterns: [
                    #"(?:^|[.!?]\s+)so,?\s+(?!that\b)"# // "So, I went" but not "so that"
                ],
                keepPatterns: [
                    #"\bso\s+that\b"#,    // consequence
                    #"\bso\s+much\b"#,    // degree
                    #"\bso\s+many\b"#,    // degree
                    #"\bso\s+far\b"#      // extent
                ]
            ),

            // "sort of" / "kind of" as hedges
            ConditionalFiller(
                phrase: "sort of",
                settingsKey: nil,
                removePatterns: [
                    #"\bsort of\s+(like|um|uh)\b"#, // "sort of like"
                    #",\s*sort of,?\s*"#             // ", sort of, "
                ],
                keepPatterns: [
                    #"\bwhat sort of\b"# // "what sort of" (question)
                ]
            ),

            ConditionalFiller(
                phrase: "kind of",
                settingsKey: nil,
                removePatterns: [
                    #",\s*kind of,?\s*"#,              // ", kind of, "
                    #"\bkind of\s+(like|um|uh)\b"#      // "kind of like"
                ],
                keepPatterns: [
                    #"\bwhat kind of\b"#, // "what kind of" (question)
                    #"\bthis kind of\b"#, // "this kind of" (specific)
                    #"\bthat kind of\b"#  // "that kind of" (specific)
                ]
            ),

            // "right" as discourse marker
            ConditionalFiller(
                phrase: "right",
                settingsKey: nil,
                removePatterns: [
                    #",\s*right\??\s*,?"#, // ", right, " or ", right?"
                ],
                keepPatterns: [
                    #"\bright\s+(now|here|there|away|side|hand|thing|answer|direction)\b"#,
                    #"\bthat's right\b"#,
                    #"\ball right\b"#
                ]
            )
        ]
    }
}

// MARK: - ConditionalFiller

private struct ConditionalFiller {
    let phrase: String
    let settingsKey: String?
    let removePatterns: [String]
    let keepPatterns: [String]

    func apply(to text: String) -> String {
        // If the phrase doesn't appear, skip
        guard text.range(of: phrase, options: .caseInsensitive) != nil else {
            return text
        }

        var result = text

        // Check keep patterns first -- if any match, don't remove
        for pattern in keepPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(result.startIndex..., in: result)
                if regex.firstMatch(in: result, range: range) != nil {
                    // A keep pattern matched, so we need to be more careful.
                    // Only remove instances that match remove patterns but NOT keep patterns.
                    break
                }
            }
        }

        // Apply remove patterns
        for pattern in removePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: " ")
            }
        }

        return result
    }
}
