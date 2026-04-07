import Foundation

struct TranscriptionRecord: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let rawText: String
    let cleanedText: String
    let durationSeconds: Double
    let wordCount: Int

    init(rawText: String, cleanedText: String, durationSeconds: Double) {
        self.id = UUID()
        self.timestamp = Date()
        self.rawText = rawText
        self.cleanedText = cleanedText
        self.durationSeconds = durationSeconds
        self.wordCount = cleanedText.split(separator: " ").count
    }
}
