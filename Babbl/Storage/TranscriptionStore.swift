import Foundation
import os.log

final class TranscriptionStore {
    private static let logger = Logger(subsystem: "com.babbl.app", category: "TranscriptionStore")
    private static let maxRecords = 1000

    private let fileURL: URL
    private let useEncryption: Bool
    private(set) var records: [TranscriptionRecord] = []

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Babbl", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
        self.fileURL = dir.appendingPathComponent("transcription_history.enc")
        self.useEncryption = true
        self.records = Self.load(from: fileURL, encrypted: true)

        // Migrate from old plaintext file if it exists
        let legacyURL = dir.appendingPathComponent("transcription_history.json")
        if records.isEmpty, let legacyRecords = Self.loadPlaintext(from: legacyURL), !legacyRecords.isEmpty {
            Self.logger.info("Migrating \(legacyRecords.count) records from plaintext to encrypted storage")
            records = legacyRecords
            persist()
            // Remove the plaintext file after successful migration
            try? FileManager.default.removeItem(at: legacyURL)
        }
    }

    /// Test-only initializer (no encryption, direct file path)
    init(fileURL: URL) {
        self.fileURL = fileURL
        self.useEncryption = false
        self.records = Self.load(from: fileURL, encrypted: false)
    }

    func save(_ record: TranscriptionRecord) {
        records.insert(record, at: 0)
        if records.count > Self.maxRecords {
            records = Array(records.prefix(Self.maxRecords))
        }
        persist()
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        guard let jsonData = try? encoder.encode(records) else {
            Self.logger.error("Failed to encode transcription history")
            return
        }

        do {
            let dataToWrite: Data
            if useEncryption {
                dataToWrite = try HistoryCrypto.encrypt(jsonData)
            } else {
                dataToWrite = jsonData
            }
            try dataToWrite.write(to: fileURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        } catch {
            Self.logger.error("Failed to write transcription history: \(error.localizedDescription)")
        }
    }

    private static func load(from url: URL, encrypted: Bool) -> [TranscriptionRecord] {
        guard let data = try? Data(contentsOf: url) else { return [] }

        let jsonData: Data
        if encrypted {
            guard let decrypted = try? HistoryCrypto.decrypt(data) else {
                Self.logger.error("Failed to decrypt transcription history")
                return []
            }
            jsonData = decrypted
        } else {
            jsonData = data
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([TranscriptionRecord].self, from: jsonData)) ?? []
    }

    private static func loadPlaintext(from url: URL) -> [TranscriptionRecord]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode([TranscriptionRecord].self, from: data)
    }
}
