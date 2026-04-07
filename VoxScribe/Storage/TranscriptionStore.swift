import Foundation

final class TranscriptionStore {
    private let fileURL: URL
    private(set) var records: [TranscriptionRecord] = []

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("VoxScribe", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("transcription_history.json")
        self.records = Self.load(from: fileURL)
    }

    init(fileURL: URL) {
        self.fileURL = fileURL
        self.records = Self.load(from: fileURL)
    }

    func save(_ record: TranscriptionRecord) {
        records.insert(record, at: 0)
        persist()
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(records) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func load(from url: URL) -> [TranscriptionRecord] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([TranscriptionRecord].self, from: data)) ?? []
    }
}
